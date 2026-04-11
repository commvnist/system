: "${OBSIDIAN_MOVIES_DIR:=${HOME}/Documents/naek/movies}"
_OBSIDIAN_MOVIE_ENTRY_SCRIPT="${${(%):-%x}:A:h}/obsidian_movie_entry.py"

obsidian_movie_entry() {
  OBSIDIAN_MOVIES_DIR="${OBSIDIAN_MOVIES_DIR}" python3 "${_OBSIDIAN_MOVIE_ENTRY_SCRIPT}" "$@"
}
