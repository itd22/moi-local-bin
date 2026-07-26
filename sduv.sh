export UV_CONCURRENT_DOWNLOADS=4
export UV_BUILD_JOBS=$(nproc)
export UV_LINK_MODE="symlink"
export UV_COMPILE_BYTECODE=1 # compile once run many times
export UV_HTTP_TIMEOUT=30
export UV_PREFER_INDEX=1
export UV_CACHE_DIR="$HOME/.cache/uv"
export TMPDIR=/tmp

# uvp set global venv by project name
uvp() { 
  UV_PROJECT_ENVIRONMENT="$HOME/pyenvs/env-$(basename "$PWD")" uv "$@"
 } 

# uvprp run with global venv
uvrp() { 
  uv run python "$@"
 } 

