export HOMEBREW_MAKE_JOBS=$(nproc)
export HOMEBREW_BOOTSTRAP_LDFLAGS="-fuse-ld=mold"
export HOMEBREW_BOOTSTRAP_CXXFLAGS="-fuse-ld=mold -O3 -march=znver3 -mtune=znver3"
export HOMEBREW_BOOTSTRAP_CFLAGS="-fuse-ld=mold -O3 -march=znver3 -mtune=znver3"
export HOMEBREW_TEMP="/tmp/homebrew-build"
export HOMEBREW_NO_INSTALL_CLEANUP=1
export LDFLAGS="-fuse-ld=mold"
export CFLAGS="-O3 -march=znver3 -mtune=znver3"
export CXXFLAGS="$CFLAGS"
export HOMEBREW_NO_ENV_FILTERING=1 # to check
alias brew-install-fast='brew install  --force-bottle  '
alias brew-install-build-optimized-TO_VERIFY-ALIAS='HOMEBREW_OPTIMIZATION_LEVEL=native HOMEBREW_ARCH=x86-64-v3 brew install --build-from-source '
alias brew-installed-by-user='brew leaves > /tmp/brew-user_installed.txt '
alias brew-prefix='brew --prefix '
alias brew-cleanall='brew cleanup -s --verbose ;  brew cleanup --prune=all ; brew uninstall   $(brew list); brew doctor '
alias brew-clean-emptied='brew cleanup -s --verbose ;  brew cleanup --prune=all ; brew doctor '
alias brew-cache='brew --cache '
alias brew-pin='brew pin '
alias brew-un-pin='brew unpin '
alias brew-list-pinned='brew list --pinned '
brew-install-build-optimized()
{
    export V=1
    export VERBOSE=1
    export CMAKE_VERBOSE_MAKEFILE=ON
    export CARGO_TERM_VERBOSE=true
    export CARGO_TERM_COLOR=never

    set -o pipefail

    brew install \
        --build-from-source \
        --verbose \
        "$@" 2>&1 | tee /tmp/brew-build-$(date +%Y%m%d-%H%M%S).log
}
brew-install-build-optimized-keep-var-tmp()
{
    export V=1
    export VERBOSE=1
    export CMAKE_VERBOSE_MAKEFILE=ON
    export CARGO_TERM_VERBOSE=true
    export CARGO_TERM_COLOR=never

    set -o pipefail

    brew install \
        --build-from-source \
        --keep-tmp \
        --verbose \
        "$@" 2>&1 | tee /tmp/brew-build-$(date +%Y%m%d-%H%M%S).log
}
