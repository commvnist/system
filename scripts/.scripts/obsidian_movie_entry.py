#!/usr/bin/env python3
"""Create an Obsidian movie entry from a TMDB URL or interactive search."""

from __future__ import annotations

import argparse
import html as html_lib
import json
import os
import re
import sys
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal, InvalidOperation
from pathlib import Path

MAX_SEARCH_RESULTS = 10
REQUEST_TIMEOUT_SECONDS = 15
TMDB_BASE_URL = "https://www.themoviedb.org"
DEFAULT_MOVIES_DIR = Path("~/Documents/naek/movies").expanduser()


@dataclass(frozen=True)
class SearchResult:
    title: str
    year: str
    description: str
    url: str


@dataclass(frozen=True)
class MovieMetadata:
    title: str
    year: str
    genres: list[str]
    directors: list[str]
    cast: list[str]


def eprint(message: str) -> None:
    print(message, file=sys.stderr)


def clean_text(value: str) -> str:
    """Strip tags/entities and collapse whitespace from scraped TMDB fragments."""
    without_tags = re.sub(r"<[^>]+>", "", value)
    unescaped = html_lib.unescape(without_tags)
    return re.sub(r"\s+", " ", unescaped).strip()


def fetch_html(url: str) -> str:
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": (
                "Mozilla/5.0 (X11; Linux x86_64; rv:120.0) "
                "Gecko/20100101 Firefox/120.0"
            ),
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.5",
        },
    )
    with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT_SECONDS) as resp:
        return resp.read().decode("utf-8", errors="replace")


def validate_tmdb_movie_url(url: str) -> str:
    parsed = urllib.parse.urlparse(url.strip())
    host = parsed.netloc.lower()

    if parsed.scheme not in {"http", "https"}:
        raise ValueError("URL must use http or https")
    if host not in {"www.themoviedb.org", "themoviedb.org"}:
        raise ValueError("URL must be on themoviedb.org")
    if not parsed.path.startswith("/movie/"):
        raise ValueError("URL path must start with /movie/")

    return urllib.parse.urlunparse(
        ("https", "www.themoviedb.org", parsed.path, "", parsed.query, "")
    )


def search_tmdb(query: str) -> list[SearchResult]:
    encoded = urllib.parse.quote(query)
    search_url = f"{TMDB_BASE_URL}/search?query={encoded}"
    eprint(f"Searching {search_url} ...")
    html = fetch_html(search_url)

    movie_sec_match = re.search(
        r'<div class="search_results movie[^"]*">\s*'
        r'<div class="results flex">(.*?)<div class="pagination_wrapper">',
        html,
        re.DOTALL,
    )
    if not movie_sec_match:
        return []

    section = movie_sec_match.group(1)
    card_chunks = re.split(r'(?=<div id="[0-9a-f]+" class="card v4 tight")', section)

    results: list[SearchResult] = []
    for chunk in card_chunks:
        if not chunk.strip():
            continue

        href_match = re.search(r'href="(/movie/[^"]+)"', chunk)
        if not href_match:
            continue

        title_match = re.search(r"<h2[^>]*>\s*<span>([^<]+)</span>", chunk)
        year_match = re.search(
            r'<span class="release_date">[^<]*?(\d{4})[^<]*</span>',
            chunk,
        )
        desc_match = re.search(r'<div class="overview">\s*<p>(.*?)</p>', chunk, re.DOTALL)

        results.append(
            SearchResult(
                title=clean_text(title_match.group(1)) if title_match else "Unknown",
                year=year_match.group(1) if year_match else "",
                description=clean_text(desc_match.group(1)) if desc_match else "(No description)",
                url=f"{TMDB_BASE_URL}{href_match.group(1)}",
            )
        )
        if len(results) >= MAX_SEARCH_RESULTS:
            break

    return results


def prompt_search() -> str:
    """Interactive search and selection. Returns the selected TMDB movie URL."""
    query = input("Search TMDB: ").strip()
    if not query:
        raise SystemExit("No query entered.")

    try:
        results = search_tmdb(query)
    except Exception as exc:
        raise SystemExit(f"Error searching: {exc}") from exc

    if not results:
        raise SystemExit("No results found.")

    print()
    for index, result in enumerate(results, 1):
        label = f"{result.title} ({result.year})" if result.year else result.title
        short_desc = result.description
        if len(short_desc) > 120:
            short_desc = f"{short_desc[:117]}..."
        print(f"{index}. {label}")
        print(f"   {short_desc}")
        print()

    while True:
        choice = input(f"Select a movie (1-{len(results)}): ").strip()
        try:
            idx = int(choice) - 1
        except ValueError:
            idx = -1

        if 0 <= idx < len(results):
            return results[idx].url

        print(f"Please enter a number between 1 and {len(results)}.")


def normalize_rating(value: str) -> str:
    raw = value.strip()
    if raw == "":
        return ""

    try:
        rating = Decimal(raw)
    except InvalidOperation as exc:
        raise ValueError("rating must be a plain number") from exc

    if not rating.is_finite():
        raise ValueError("rating must be a finite number")

    normalized = format(rating.normalize(), "f")
    if "." in normalized:
        normalized = normalized.rstrip("0").rstrip(".")
    return normalized or "0"


def prompt_rating() -> str:
    while True:
        value = input("Rating (number, or leave blank): ").strip()
        try:
            return normalize_rating(value)
        except ValueError:
            print("Please enter a plain number, for example 1, 3.5, or 8.")


def normalize_watched_date(value: str) -> str:
    normalized = value.strip().replace("/", "-")
    datetime.strptime(normalized, "%Y-%m-%d")
    return normalized


def prompt_watched_date() -> str:
    prompt = 'When did you watch it? (YYYY/MM/DD, blank = today, "no" = leave blank): '
    while True:
        value = input(prompt).strip()
        if value == "":
            return date.today().strftime("%Y-%m-%d")
        if value.lower() == "no":
            return ""
        try:
            return normalize_watched_date(value)
        except ValueError:
            print("Please enter a date as YYYY/MM/DD or YYYY-MM-DD.")


def parse_tmdb(html: str) -> MovieMetadata:
    title_match = re.search(
        r'<h2[^>]*>\s*<a[^>]*>([^<]+)</a>\s*<span class="tag release_date">',
        html,
    )
    title = clean_text(title_match.group(1)) if title_match else "Unknown"

    year_match = re.search(r'<span class="tag release_date">\((\d{4})\)</span>', html)
    year = year_match.group(1) if year_match else "Unknown"

    genres: list[str] = []
    genres_match = re.search(r'<span class="genres">(.*?)</span>', html, re.DOTALL)
    if genres_match:
        genres = [
            clean_text(match).lower()
            for match in re.findall(r"<a[^>]*>([^<]+)</a>", genres_match.group(1))
        ]

    directors: list[str] = []
    crew_match = re.search(r'<ol class="people no_image">(.*?)</ol>', html, re.DOTALL)
    if crew_match:
        profiles = re.findall(
            r'<li class="profile">(.*?)</li>',
            crew_match.group(1),
            re.DOTALL,
        )
        for profile in profiles:
            char_match = re.search(r'<p class="character">([^<]+)</p>', profile)
            name_match = re.search(r"<p>\s*<a[^>]*>([^<]+)</a>\s*</p>", profile)
            if not char_match or not name_match:
                continue

            roles = [role.strip() for role in clean_text(char_match.group(1)).split(",")]
            if "Director" in roles:
                directors.append(clean_text(name_match.group(1)))

    cast = parse_cast(html)
    return MovieMetadata(title=title, year=year, genres=genres, directors=directors, cast=cast)


def parse_cast(html: str) -> list[str]:
    cast: list[str] = []
    cast_match = re.search(r'<ol class="people scroller">(.*?)</ol>', html, re.DOTALL)
    if cast_match:
        for card in re.findall(r'<li class="card">(.*?)</li>', cast_match.group(1), re.DOTALL):
            name_match = re.search(r"<p>\s*<a[^>]*>([^<]+)</a>\s*</p>", card)
            if name_match:
                cast.append(clean_text(name_match.group(1)))
            if len(cast) >= 5:
                return cast

    cast_section = re.search(r"Top Billed Cast.*?<ol[^>]*>(.*?)</ol>", html, re.DOTALL)
    if cast_section:
        for card in re.findall(r"<li[^>]*>(.*?)</li>", cast_section.group(1), re.DOTALL):
            name_match = re.search(r"<p>\s*<a[^>]*>([^<]+)</a>\s*</p>", card)
            if name_match:
                cast.append(clean_text(name_match.group(1)))
            if len(cast) >= 5:
                break

    return cast


def yaml_scalar(value: str) -> str:
    if value == "":
        return ""
    return json.dumps(value, ensure_ascii=False)


def yaml_list(name: str, values: list[str]) -> list[str]:
    if not values:
        return [f"{name}: []"]
    return [f"{name}:"] + [f"  - {yaml_scalar(value)}" for value in values]


def build_entry(metadata: MovieMetadata, rating: str = "", finished: str = "") -> str:
    rating_value = normalize_rating(rating)
    lines = [
        "---",
        f"year: {metadata.year}",
        f"finished: {finished}",
        *yaml_list("genre", metadata.genres),
        *yaml_list("directors", metadata.directors),
        *yaml_list("cast", metadata.cast),
        f"rating: {rating_value}",
        "tags:",
        "  - movie",
        "---",
    ]
    return "\n".join(lines) + "\n"


def sanitize_filename(title: str) -> str:
    name = html_lib.unescape(title)
    name = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "", name)
    name = re.sub(r"\s+", " ", name).strip(" .")
    if not name:
        raise ValueError("movie title produced an empty filename")
    return name


def movies_dir() -> Path:
    return Path(os.environ.get("OBSIDIAN_MOVIES_DIR", str(DEFAULT_MOVIES_DIR))).expanduser()


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create an Obsidian movie note from a TMDB movie URL.",
    )
    parser.add_argument(
        "url",
        nargs="?",
        help="TMDB movie URL. If omitted, search TMDB interactively.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)

    if args.url:
        try:
            url = validate_tmdb_movie_url(args.url)
        except ValueError as exc:
            eprint(f"Invalid TMDB URL: {exc}")
            return 1
        rating = ""
        finished = date.today().strftime("%Y-%m-%d")
    else:
        url = prompt_search()
        rating = prompt_rating()
        finished = prompt_watched_date()

    eprint(f"Fetching {url} ...")

    try:
        html = fetch_html(url)
    except Exception as exc:
        eprint(f"Error fetching URL: {exc}")
        return 1

    metadata = parse_tmdb(html)
    if metadata.title == "Unknown":
        eprint("Error: movie title not found; TMDB page structure may have changed.")
        return 1

    eprint(f"Title    : {metadata.title} ({metadata.year})")
    eprint(f"Genres   : {', '.join(metadata.genres) or '(none found)'}")
    eprint(f"Directors: {', '.join(metadata.directors) or '(none found)'}")
    eprint(f"Cast     : {', '.join(metadata.cast) or '(none found)'}")

    if not metadata.cast:
        eprint("Warning: cast section not found; page structure may have changed.")

    try:
        filename = sanitize_filename(metadata.title)
    except ValueError as exc:
        eprint(f"Error: {exc}")
        return 1

    target_dir = movies_dir()
    target_dir.mkdir(parents=True, exist_ok=True)
    filepath = target_dir / f"{filename}.md"

    try:
        with filepath.open("x", encoding="utf-8") as handle:
            handle.write(build_entry(metadata, rating, finished))
    except FileExistsError:
        eprint(f"File already exists: {filepath}")
        return 1
    except OSError as exc:
        eprint(f"Error writing file: {exc}")
        return 1

    print(f"Created: {filepath}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
