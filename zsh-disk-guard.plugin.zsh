#!/bin/env zsh
0="${ZERO:-${${0:#$ZSH_ARGZERO}:-${(%):-%N}}}"
0="${ZERO:-${${${(M)${0::=${(%):-%x}}:#/*}:-$PWD/$0}:A}}"
local ZERO="$0"

if [[ ${zsh_loaded_plugins[-1]} != */zsh-disk-guard && -z ${fpath[(r)${0:h}]} ]] {
    fpath+=( "${0:h}" )
}

source ${0:A:h}/zsh-disk-guard.zsh
