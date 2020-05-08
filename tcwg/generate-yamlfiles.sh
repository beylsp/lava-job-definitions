#!/bin/bash

set -euf -o pipefail

top=$(git rev-parse --show-toplevel)

generate_yamlfiles ()
{
    (
    local yaml_in="$1"

    local dir="${yaml_in%%.yaml.in}"

    if [ ! -d "$dir" ]; then
	echo "WARNING: definition directory $dir does not exist" >&2
	echo "WARNING: not generating anything from $yaml_in" >&2
	return
    fi

    local def_file yaml_file

    while IFS= read -r -d '' def_file; do
	yaml_file="$dir-$(basename "$def_file" .def).yaml"
        echo "# Auto generated from ${yaml_in#$top/} and ${def_file#$top/}. Do not edit." > "$yaml_file"
	$top/tcwg/cpp-script.sh $(cat "$def_file") -i "$yaml_in" \
				     >> "$yaml_file"
        $top/tcwg/validate-checksum.sh --generate true "$yaml_file"
    done < <(find "$dir" -name "*.def" -print0)
    )
}

while IFS= read -r -d '' i; do
    generate_yamlfiles "$i"
done < <(find "$top" -name "*.yaml.in" -print0)
