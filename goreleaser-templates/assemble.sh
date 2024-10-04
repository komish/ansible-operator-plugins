#!/usr/bin/env bash
set -e

test -n "$TEMPLATE_OS" || { echo "TEMPLATE_OS is not set" && exit 1 ;}
test -n "$TEMPLATE_ARCH" || { echo "TEMPLATE_ARCH is not set" && exit 1 ;}

# build the "builds" and "hooks"
export buildsOut=$(
    yq -e '(
    .builds[0].goos += env(TEMPLATE_OS) |
    .builds[0].goarch += env(TEMPLATE_ARCH)
    )' builds-template.yml
)

echo "$buildsOut" | yq

# Build the "dockers"
export __imageTemplate=$(yq -e '(.imageTemplateString + env(TEMPLATE_ARCH))' fragments.yml)
export __buildflag=$(yq -e '(.buildflagTemplateString + env(TEMPLATE_OS) + "/" +env(TEMPLATE_ARCH))' fragments.yml)
export dockers_out=$(
    yq -e '(
    .goos = env(TEMPLATE_OS) |
    .goarch = env(TEMPLATE_ARCH) |
    .image_templates += strenv(__imageTemplate) |
    .build_flag_templates += strenv(__buildflag)
    )' docker-template.yml
)

echo 'dockers: []' | yq -e '(.dockers += env(dockers_out))' 

# Print the non-templated footer.
cat footer.yml