alias c='clear;'
# alias cargo='nocorrect cargo'
alias difft-all='c difft --display=side-by-side-show-both --context 1000 '
alias difft-only-diff='difft --display=side-by-side '
alias h='history '
alias ltr='ls -latr'
alias okular-netloop='firejail --name=safe_okular --net=lo --private --seccomp okular  '
alias okular-safe='firejail --net=none --private=. --seccomp  --private-bin=okular  okular '
alias okular-safe-private-bin='firejail --net=none --private --seccomp  --private-bin=okular  okular '
alias okular-safe-tmp='  firejail \
    --net=none \
    --private \
    --whitelist=/home/sd/Documents \
    okular /home/sd/Documents/file.pdf'
alias okular-netsnif='sudo firejail --join-network=safe_okular tcpdump -vv -n'
alias okular-netloop-watch='firemon --name=safe_okular --netstats '
