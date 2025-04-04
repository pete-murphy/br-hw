set dotenv-load := true
set quiet

default:
    just --list

run:
    #!/usr/bin/env bash
    set -eu
    if [[ -z "$MAPBOX_ACCESS_TOKEN" ]]; then
        echo "Error: Environment variable MAPBOX_ACCESS_TOKEN is not set."
        echo "You'll need an access token to run this project locally."
        exit 1
    fi
    export VITE_APP_MAPBOX_ACCESS_TOKEN="$MAPBOX_ACCESS_TOKEN"
    vite

sort flag="--write":
    #!/usr/bin/env bash
    set -eu
    rustywind {{flag}} --custom-regex "\bclass[\s(<|]+\"([^\"]*)\"" .
    rustywind {{flag}} --custom-regex "\bclass[\s(]+\"[^\"]*\"[\s+]+\"([^\"]*)\"" .
    rustywind {{flag}} --custom-regex "\bclass[\s<|]+\"[^\"]*\"\s*\+{2}\s*\" ([^\"]*)\"" .
    rustywind {{flag}} --custom-regex "\bclass[\s<|]+\"[^\"]*\"\s*\+{2}\s*\" [^\"]*\"\s*\+{2}\s*\" ([^\"]*)\"" .
    rustywind {{flag}} --custom-regex "\bclass[\s<|]+\"[^\"]*\"\s*\+{2}\s*\" [^\"]*\"\s*\+{2}\s*\" [^\"]*\"\s*\+{2}\s*\" ([^\"]*)\"" .
    rustywind {{flag}} --custom-regex "\bclassList[\s\[\(]+\"([^\"]*)\"" .
    rustywind {{flag}} --custom-regex "\bclassList[\s\[\(]+\"[^\"]*\",\s[^\)]+\)[\s\[\(,]+\"([^\"]*)\"" .
    rustywind {{flag}} --custom-regex "\bclassList[\s\[\(]+\"[^\"]*\",\s[^\)]+\)[\s\[\(,]+\"[^\"]*\",\s[^\)]+\)[\s\[\(,]+\"([^\"]*)\"" .
