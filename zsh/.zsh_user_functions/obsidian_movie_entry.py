#!/usr/bin/env python3
"""Create an Obsidian movie entry from a TMDB URL."""

import sys
import re
import os
import urllib.request
from datetime import date


def fetch_html(url):
    req = urllib.request.Request(url, headers={
        'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
    })
    with urllib.request.urlopen(req, timeout=15) as resp:
        return resp.read().decode('utf-8', errors='replace')


def parse_tmdb(html):
    # Title: <h2 ...><a href="...">Title</a> <span class="tag release_date">(YEAR)</span></h2>
    title_match = re.search(
        r'<h2[^>]*>\s*<a[^>]*>([^<]+)</a>\s*<span class="tag release_date">',
        html
    )
    title = title_match.group(1).strip() if title_match else 'Unknown'

    # Year: (YYYY) in release_date span
    year_match = re.search(r'<span class="tag release_date">\((\d{4})\)</span>', html)
    year = year_match.group(1) if year_match else 'Unknown'

    # Genres: <span class="genres"><a ...>Genre</a>, ...</span>
    genres_match = re.search(r'<span class="genres">(.*?)</span>', html, re.DOTALL)
    genres = []
    if genres_match:
        genres = [
            g.strip().lower()
            for g in re.findall(r'<a[^>]*>([^<]+)</a>', genres_match.group(1))
        ]

    # Directors: from <ol class="people no_image"> where character == "Director"
    crew_match = re.search(r'<ol class="people no_image">(.*?)</ol>', html, re.DOTALL)
    directors = []
    if crew_match:
        for profile in re.findall(r'<li class="profile">(.*?)</li>', crew_match.group(1), re.DOTALL):
            char_match = re.search(r'<p class="character">([^<]+)</p>', profile)
            name_match = re.search(r'<p>\s*<a[^>]*>([^<]+)</a>\s*</p>', profile)
            if char_match and name_match and 'Director' in [r.strip() for r in char_match.group(1).split(',')]:
                directors.append(name_match.group(1).strip())

    # Top 5 cast: from <ol class="people scroller"> (top-billed cast section)
    cast = []
    cast_match = re.search(r'<ol class="people scroller">(.*?)</ol>', html, re.DOTALL)
    if cast_match:
        for card in re.findall(r'<li class="card">(.*?)</li>', cast_match.group(1), re.DOTALL):
            name_match = re.search(r'<p>\s*<a[^>]*>([^<]+)</a>\s*</p>', card)
            if name_match:
                cast.append(name_match.group(1).strip())
            if len(cast) >= 5:
                break

    # Fallback: try alternate cast section pattern
    if not cast:
        cast_section = re.search(
            r'Top Billed Cast.*?<ol[^>]*>(.*?)</ol>',
            html, re.DOTALL
        )
        if cast_section:
            for card in re.findall(r'<li[^>]*>(.*?)</li>', cast_section.group(1), re.DOTALL):
                name_match = re.search(r'<p>\s*<a[^>]*>([^<]+)</a>\s*</p>', card)
                if name_match:
                    cast.append(name_match.group(1).strip())
                if len(cast) >= 5:
                    break

    return title, year, genres, directors, cast


def build_entry(title, year, genres, directors, cast):
    today = date.today().strftime('%Y-%m-%d')
    lines = [
        '---',
        f'year: {year}',
        f'finished: {today}',
        'genre:',
    ]
    for g in genres:
        lines.append(f'  - {g}')
    lines.append('directors:')
    for d in directors:
        lines.append(f'  - {d}')
    lines.append('cast:')
    for c in cast:
        lines.append(f'  - {c}')
    lines += [
        'rating: ',
        'tags:',
        '  - movie',
        '---',
    ]
    return '\n'.join(lines) + '\n'


def sanitize_filename(title):
    name = re.sub(r'[<>:"/\\|?*]', '', title)
    name = re.sub(r'\s+', ' ', name).strip()
    return name


MOVIES_DIR = os.environ.get('OBSIDIAN_MOVIES_DIR', os.path.expanduser('~/Documents/naek/movies'))


def main():
    if len(sys.argv) < 2:
        print('Usage: obsidian_movie_entry <tmdb_url>', file=sys.stderr)
        sys.exit(1)

    url = sys.argv[1]
    print(f'Fetching {url} ...', file=sys.stderr)

    try:
        html = fetch_html(url)
    except Exception as e:
        print(f'Error fetching URL: {e}', file=sys.stderr)
        sys.exit(1)

    title, year, genres, directors, cast = parse_tmdb(html)

    print(f'Title    : {title} ({year})', file=sys.stderr)
    print(f'Genres   : {", ".join(genres) or "(none found)"}', file=sys.stderr)
    print(f'Directors: {", ".join(directors) or "(none found)"}', file=sys.stderr)
    print(f'Cast     : {", ".join(cast) or "(none found)"}', file=sys.stderr)

    if not cast:
        print('Warning: cast section not found — page structure may have changed.', file=sys.stderr)

    content = build_entry(title, year, genres, directors, cast)

    filename = sanitize_filename(title)
    filepath = os.path.join(MOVIES_DIR, f'{filename}.md')

    if os.path.exists(filepath):
        print(f'File already exists: {filepath}', file=sys.stderr)
        sys.exit(1)

    os.makedirs(MOVIES_DIR, exist_ok=True)
    with open(filepath, 'w') as f:
        f.write(content)

    print(f'Created: {filepath}')


if __name__ == '__main__':
    main()
