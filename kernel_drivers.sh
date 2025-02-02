while (( ${#} )); do
    case ${1} in
        "-a"|"--audio") AUDIO=true ;;
        "-i"|"--init") INIT=true ;;
        "-t"|"--tag") shift; TAG=${1} ;;
        "-u"|"--update") UPDATE=true ;;
    esac
    shift
done

[[ -n ${INIT} && -n ${UPDATE} ]] && { echo "Both init and update were specified!"; exit; }

[[ -z ${TAG} ]] && { echo "No tag was specified!"; exit; }

SUBFOLDER_WLAN=drivers/staging
REPOS_WLAN=( "fw-api" "qcacld-3.0" "qca-wifi-host-cmn" )
URL_WLAN=https://source.codeaurora.org/quic/la/platform/vendor/qcom-opensource/wlan/

for REPO in "${REPOS_WLAN[@]}"; do
    echo "${REPO}"
    if ! git ls-remote --exit-code "${REPO}" &>/dev/null; then
        git remote add "${REPO}" "${URL_WLAN}${REPO}"
    fi
    git fetch "${REPO}" "${TAG}"
    if [[ -n ${INIT} ]]; then
        git merge --allow-unrelated-histories -s ours --no-commit FETCH_HEAD
        git read-tree --prefix="${SUBFOLDER_WLAN}/${REPO}" -u FETCH_HEAD
        git commit --no-edit -m "staging: ${REPO}: Checkout at ${TAG}" -s
        elif [[ -n ${UPDATE} ]]; then
        git merge --no-edit -m "staging: ${REPO}: Merge tag '${TAG}' into $(git rev-parse --abbrev-ref HEAD)" \
                  -X subtree="${SUBFOLDER_WLAN}/${REPO}" FETCH_HEAD
    fi
done

[[ -z ${AUDIO} ]] && { exit; }

SUBFOLDER_AUDIO=techpack/audio
REPOS_AUDIO=( "audio-kernel" )
URL_AUDIO=https://source.codeaurora.org/quic/la/platform/vendor/opensource/

for REPO in "${REPOS_AUDIO[@]}"; do
    echo "${REPO}"
    if ! git ls-remote --exit-code "${REPO}" &>/dev/null; then
        git remote add "${REPO}" "${URL_AUDIO}${REPO}"
    fi
    git fetch "${REPO}" "${TAG}"
    if [[ -n ${INIT} ]]; then
        git merge --allow-unrelated-histories -s ours --no-commit FETCH_HEAD
        git read-tree --prefix="${SUBFOLDER_AUDIO}" -u FETCH_HEAD
        git commit --no-edit -m "staging: ${REPO}: Checkout at ${TAG}" -s
        elif [[ -n ${UPDATE} ]]; then
        git merge --no-edit -m "staging: ${REPO}: Merge tag '${TAG}' into $(git rev-parse --abbrev-ref HEAD)" \
                  -X subtree="${SUBFOLDER_AUDIO}" FETCH_HEAD
    fi
done
