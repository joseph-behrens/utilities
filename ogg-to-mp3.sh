#!/bin/bash

function get_attribute {
  result=$(jq -r --arg key "$1" '.[$key]' <<< "$2")
  echo $result
}

MusicPath="$1"
pushd $MusicPath
for file in *.ogg;
do
  echo "Processing $file..."
  [[ -f "$file" ]] || continue
  metadataogg=$(ffprobe -v quiet -print_format json -show_format -show_streams "$file" | /usr/bin/jq '.streams[].tags')
  echo "Meta data: $metadataogg"
  tracktotal=$(get_attribute TRACKTOTAL "$metadataogg")
  tracknumber=$(get_attribute track "$metadataogg")
  trackname=$(get_attribute TITLE "$metadataogg")
  artist=$(get_attribute ARTIST "$metadataogg")
  album=$(get_attribute ALBUM "$metadataogg")
  if [[ "$file" =~ ^([0-9]+)\.(.*)$ ]]; then
    # BASH_REMATCH[1] = digits, BASH_REMATCH[2] = rest of name
    base="${BASH_REMATCH[2]}"
  else
    base="$file"
  fi
  newname="${base//_/ }"
  mv -- "$file" "$newname"
  echo "Track name is $trackname"
  echo "Track number is $tracknumber"
  ffmpeg -i "$newname" -metadata artist="$artist" -metadata album="$album" -metadata title="$trackname" -metadata track="$tracknumber/$tracktotal" "${newname%.*}.mp3"
done
cd ..

declare -a track_order_array=()

function add_album {
	local artist="$1" album="$2" tracks="$3"
	local json="{\"Artist\":\"$artist\",\"Album\":\"$album\",\"Tracks\":$tracks}"
        track_order_array+=("$json")
}

function get_attribute {
  result=$(jq -r --arg key "$1" '.[$key]' <<< "$2")
  echo $result
}

for d in */;
do
  #echo "=========================================================================="
  #echo "Working dir is now $d"
  #echo "=========================================================================="
  pushd "$d" > /dev/null
  tracks_array=()
  for file in *.ogg;
  do
    #echo "=========================================================================="
    #echo "Working on file $file..."
    #echo "=========================================================================="
    trackdata=$(ffprobe -v quiet -print_format json -show_format -show_streams "$file" | jq '.streams[].tags')
    tracktotal=$(get_attribute TRACKTOTAL "$trackdata")
    tracknumber=$(get_attribute track "$trackdata")
    trackname=$(get_attribute TITLE "$trackdata")
    artist=$(get_attribute ARTIST "$trackdata")
    album=$(get_attribute ALBUM "$trackdata")
    tracks_array+=("\"$tracknumber\": \"$trackname\"")
    #echo "============================================================="
    #echo "Tracks array is $tracks_array"
    #echo "============================================================="
  done
  tracks_json="{$(IFS=,; echo "${tracks_array[*]}")}"
  add_album "$artist" "$album" "$tracks_json"
  #echo "==========================================================="
  #echo "UPDATED ALBUM LIST: ${track_order_array[*]}"
  #echo "==========================================================="
  popd > /dev/null
done
{
  echo "["
  for i in "${!track_order_array[@]}"; do
    if (( i == ${#track_order_array[@]} - 1 )); then
      printf '%s\n' "${track_order_array[i]}"
    else
      printf '%s,\n' "${track_order_array[i]}"
    fi
  done
  echo "]"
} > tracks.json
