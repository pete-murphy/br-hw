set dotenv-load := true

@default:
    just --list

@run:
    #!/usr/bin/env bash
    set -eu
    if [[ -z "$MAPBOX_ACCESS_TOKEN" ]]; then
        echo "Error: Environment variable MAPBOX_ACCESS_TOKEN is not set."
        echo "You'll need an access token to run this project locally."
        exit 1
    fi
    export VITE_APP_MAPBOX_ACCESS_TOKEN="$MAPBOX_ACCESS_TOKEN"
    vite

@sort:
    #!/usr/bin/env bash
    set -eu
    rustywind --write --custom-regex "\bclass[\s(<|]+\"([^\"]*)\"" .
    rustywind --write --custom-regex "\bclass[\s(]+\"[^\"]*\"[\s+]+\"([^\"]*)\"" .
    rustywind --write --custom-regex "\bclass[\s<|]+\"[^\"]*\"\s*\+{2}\s*\" ([^\"]*)\"" .
    rustywind --write --custom-regex "\bclass[\s<|]+\"[^\"]*\"\s*\+{2}\s*\" [^\"]*\"\s*\+{2}\s*\" ([^\"]*)\"" .
    rustywind --write --custom-regex "\bclass[\s<|]+\"[^\"]*\"\s*\+{2}\s*\" [^\"]*\"\s*\+{2}\s*\" [^\"]*\"\s*\+{2}\s*\" ([^\"]*)\"" .
    rustywind --write --custom-regex "\bclassList[\s\[\(]+\"([^\"]*)\"" .
    rustywind --write --custom-regex "\bclassList[\s\[\(]+\"[^\"]*\",\s[^\)]+\)[\s\[\(,]+\"([^\"]*)\"" .
    rustywind --write --custom-regex "\bclassList[\s\[\(]+\"[^\"]*\",\s[^\)]+\)[\s\[\(,]+\"[^\"]*\",\s[^\)]+\)[\s\[\(,]+\"([^\"]*)\"" .
