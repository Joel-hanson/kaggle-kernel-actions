#!/bin/bash
export KAGGLE_USERNAME=$INPUT_KAGGLE_USERNAME
export KAGGLE_KEY=$INPUT_KAGGLE_KEY
KAGGLE_FOLDER_PATH=""

pip install kaggle flake8 --upgrade

yelB=$'\e[1;33m'
fclr=$'\e[0m'

format_title() {
  # USAGE
  #   format_title "TITLE" "{h1/h2/h3}" "${color}" "{fill_character}"
  # EXMAPLE
  #   format_title "Heading 1" "h2" "$yelB" "="
  #   ============================ Heading 1 ============================

  ftitle=$1
  heading=$2
  color=$3
  fill=$4

  total_length=100
  ftitle_spacing=" "
  ftitle_border=$'\n' # variable implemented in h1 instances only
  formatted_ftitle=""

  if [[ $heading == "h1" ]]; then
    for ((i = 1; i <= $total_length; i++)); do
      ftitle_border=$ftitle_border$fill
    done
  fi

  if [[ $heading == "h1" || $heading == "h2" ]]; then
    ftitle_spacing="          "
  fi

  ftitle_fill=$((($total_length / 2) - (${#ftitle} / 2) - ${#ftitle_spacing}))

  for ((i = 0; i < $ftitle_fill; i++)); do
    formatted_ftitle=$formatted_ftitle$fill
  done

  formatted_ftitle=$formatted_ftitle$ftitle_spacing$color$ftitle$fclr$ftitle_spacing$formatted_ftitle

  # if the length of ftitle is odd, remove the last fill character

  if ((${#ftitle} % 2)); then
    formatted_ftitle="${formatted_ftitle::-1}"
  fi

  if [[ $heading == "h1" ]]; then
    formatted_ftitle=$ftitle_border$'\n'$formatted_ftitle$ftitle_border$'\n'
  fi

  printf "%s\n" "${formatted_ftitle}"
}

make_array() {
  if [ ! -z $1 ]; then
    IFS=',' read -ra my_array <<<"$(echo -e "$1" | tr -d '[:space:]')"
    array=""
    for i in "${my_array[@]}"; do
      if [ ! -z $i ]; then
        array+=\"$i\"\,
      fi
    done
    array="${array::-1}"
    echo "$array"
  else
    echo
  fi
}

check_and_apply_competitions_variables() {
  if [ -z $INPUT_COMPETITION_SOURCES ] || [[ "$INPUT_COMPETITION_SOURCES" != *"$INPUT_COMPETITION"* ]]; then
    INPUT_COMPETITION_SOURCES=$(make_array $INPUT_COMPETITION_SOURCES","$INPUT_COMPETITION",")
    format_title "The competitions have being initialized" "h2" "$yelB" "="
    echo $INPUT_COMPETITION_SOURCES
  fi
}

create_kaggle_metadata() {
  # create metadata file
  if [ -z $INPUT_KAGGLE_METADATA_PATH ]; then
    # check if the path is blank
    # TODO: We can download the metadata and code file from kaggle and make a new PR to the repo
    INPUT_DATASET_SOURCES=$(make_array $INPUT_DATASET_SOURCES)
    INPUT_KERNEL_SOURCES=$(make_array $INPUT_KERNEL_SOURCES)
    echo "
    {
      \"id\": \"${INPUT_KERNEL_ID}\",
      \"title\": \"$INPUT_KERNEL_TITLE\",
      \"code_file\": \"$INPUT_CODE_FILE_PATH\",
      \"language\": \"$INPUT_LANGUAGE\",
      \"kernel_type\": \"$INPUT_KERNEL_TYPE\",
      \"is_private\": $INPUT_IS_PRIVATE,
      \"enable_gpu\": $INPUT_ENABLE_GPU,
      \"enable_internet\": $INPUT_ENABLE_INTERNET,
      \"keywords\": [$INPUT_KERNEL_KEYWORDS],
      \"dataset_sources\": [
        $INPUT_DATASET_SOURCES
      ],
      \"kernel_sources\": [
        $INPUT_KERNEL_SOURCES
      ],
      \"competition_sources\": [
        $INPUT_COMPETITION_SOURCES
      ]
    }" >kernel-metadata.json
    format_title "The metadata file was created" "h2" "$yelB" "="
    cat kernel-metadata.json
    KAGGLE_FOLDER_PATH="."
  else
    if ! ls -d $INPUT_KAGGLE_METADATA_PATH >/dev/null 2>&1; then
      format_title "The file does not exist" "h2" "$yelB" "="
      exit 1
    else
      cp -n $INPUT_KAGGLE_METADATA_PATH .
    fi
    format_title "The metadata file already exist" "h2" "$yelB" "="
    KAGGLE_FOLDER_PATH=$(dirname $INPUT_KAGGLE_METADATA_PATH)
  fi
}

check_kernel_status() {
  KERNEL_STATUS=$(kaggle k status $INPUT_KERNEL_ID)
  RESULT=$?
  if [ $RESULT -eq 1 ]; then
    format_title "The kernel not found while checking status" "h2" "$yelB" "="
    if $INPUT_KAGGLE_MAKE_NEW_KERNEL; then
      format_title "Pushing this kernel as a new one" "h2" "$yelB" "="
    else
      echo $KERNEL_STATUS
      exit 1
    fi
  else
    if [[ "$KERNEL_STATUS" == *"has status \"complete\""* ]] || [[ $KERNEL_STATUS == *"has status \"cancelRequested\""* ]] || [[ $KERNEL_STATUS == *"has status \"cancelAcknowledged\""* ]]; then
      format_title "The Kernel ran successfully" "h2" "$yelB" "="
    else
      format_title "The Kernel is still running..." "h2" "$yelB" "="
      exit 1
    fi
  fi

}

deploy() {
  output=$(kaggle k push -p $KAGGLE_FOLDER_PATH)
  RESULT=$?
  if [ $RESULT -eq 0 ]; then
    format_title "$output" "h2" "$yelB" "="
  else
    format_title "There was an error while pushing the latest kernel" "h2" "$yelB" "="
    echo "$output"
    exit 1
  fi
}

submit_to_competition() {
  if [ -z $INPUT_SUBMITION_MESSAGE]; then
    $INPUT_SUBMITION_MESSAGE=$(git log --no-merges -1 --oneline)
  fi
  output=kaggle c submit -f $INPUT_CODE_FILE_PATH -m $INPUT_SUBMITION_MESSAGE
  RESULT=$?
  if [ $RESULT -eq 0 ]; then
    format_title "$output" "h2" "$yelB" "="
  else
    format_title "There was an error while submitting the latest kernel" "h2" "$yelB" "="
    echo "$output"
    exit 1
  fi
}

download_outputs_as_schedule() {
  KERNEL_STATUS=$(kaggle k status $INPUT_KERNEL_ID)
  RESULT=$?
  if [ $RESULT -ne 0 ]; then
    format_title "The kernel was missing while downloading the outputs - scheduling tasks" "h2" "$yelB" "="
    echo $KERNEL_STATUS
    exit 1
  fi
  if [[ $KERNEL_STATUS == *'has status "complete"'* ]] || [[ $KERNEL_STATUS == *'has status "cancelRequested"'* ]] || [[ $KERNEL_STATUS == *'has status "cancelAcknowledged"'* ]]; then
    format_title "The kernel ran successfully and started downloading the output files - scheduling tasks" "h2" "$yelB" "="
    mkdir -p $GITHUB_WORKSPACE/outputs
    output=kaggle k output $INPUT_KERNEL_ID -p $GITHUB_WORKSPACE/outputs
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
      format_title "$output" "h2" "$yelB" "="
    else
      format_title "There was an error in while downloading the outputs - scheduling tasks" "h2" "$yelB" "="
      echo "$output"
      exit 1
    fi
    zip -r $GITHUB_WORKSPACE/outputs/outputs.zip $GITHUB_WORKSPACE/outputs/*
    echo $(ls $GITHUB_WORKSPACE)
    echo $(ls $GITHUB_WORKSPACE/outputs)
    format_title "The kernel output are saved to the github artifact folder - scheduling tasks" "h2" "$yelB" "="
  else
    format_title "Kernel is still running... - scheduling tasks" "h2" "$yelB" "="
    exit 0
  fi
}

download_outputs() {
  KERNEL_STATUS=$(kaggle k status $INPUT_KERNEL_ID)
  RESULT=$?
  if [ $RESULT -ne 0 ]; then
    format_title "The kernel was missing while downloading the outputs" "h2" "$yelB" "="
    exit 1
  fi
  if [[ $KERNEL_STATUS == *'has status "complete"'* ]] || [[ $KERNEL_STATUS == *'has status "cancelRequested"'* ]] || [[ $KERNEL_STATUS == *'has status "cancelAcknowledged"'* ]]; then
    format_title "The kernel ran successfully and started downloading the output files" "h2" "$yelB" "="
    mkdir -p $GITHUB_WORKSPACE/outputs
    output=kaggle k output $INPUT_KERNEL_ID -p $GITHUB_WORKSPACE/outputs
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
      format_title "$output" "h2" "$yelB" "="
    else
      format_title "There was an error in while downloading the outputs" "h2" "$yelB" "="
      echo "$output"
      exit 1
    fi
    echo "zipping"
    zip -r $GITHUB_WORKSPACE/outputs/outputs.zip $GITHUB_WORKSPACE/outputs/*
    echo $(ls $GITHUB_WORKSPACE)
    echo $(ls $GITHUB_WORKSPACE/outputs)
    format_title "The kernel output are saved to the github artifact folder" "h2" "$yelB" "="
    exit 0
  else
    format_title "Kernel is still running... - scheduling tasks" "h2" "$yelB" "="
    sleep 5m
    download_outputs
  fi
}
# output donwload here
if $INPUT_COLLECT_OUTPUT_AS_SCHEDULE; then
  download_outputs_as_schedule
else
  # runs here
  check_and_apply_competitions_variables
  create_kaggle_metadata
  if $INPUT_DEPLOY_KERNEL; then
    check_kernel_status
    deploy
    if $INPUT_COLLECT_OUTPUT; then
      sleep 2m
      download_outputs
    fi
  fi
  if $INPUT_SUBMIT_TO_COMPETITION; then
    submit_to_competition
  fi
fi
