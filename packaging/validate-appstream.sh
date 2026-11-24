#!/bin/sh

# AppStream 1.0 predates the registered GameTool category. Keep checking every
# other validation warning and error on distributions that still ship it.
validator=$1
metadata=$2
if output=$(LC_ALL=C "$validator" validate --no-net "$metadata" 2>&1); then
    printf '%s\n' "$output"
    exit 0
else
    status=$?
fi
printf '%s\n' "$output"
if [ "$status" -eq 3 ] && "$validator" --version | grep -Eq '(^| )1\.0\.'; then
    issues=$(printf '%s\n' "$output" | grep -E '^[EW]:')
    if [ "$issues" = 'W: com.vysp3r.ProtonPlus:~: category-invalid GameTool' ]; then
        exit 0
    fi
fi
exit "$status"
