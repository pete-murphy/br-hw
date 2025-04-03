@default:
    just --list

@run:
    npx vite

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
