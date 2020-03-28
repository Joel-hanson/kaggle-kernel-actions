#!/bin/sh -l
export KAGGLE_USERNAME=$INPUT_KAGGLE_USERNAME
export KAGGLE_KEY=$INPUT_KAGGLE_KEY

pip install kaggle flake8 --upgrade

check_and_apply_competitions_variables
create_kaggle_metadata
check_kernel_status_and_deploy

check_and_apply_competitions_variables() {
  if [ -z $INPUT_COMPETITION_SOURCES || "$INPUT_COMPETITION_SOURCES" != *"$INPUT_COMPETITION"*  ]; then
    $INPUT_COMPETITION_SOURCES = $INPUT_COMPETITION_SOURCES$INPUT_COMPETITION
    echo $INPUT_COMPETITION_SOURCES
  fi
}

create_kaggle_metadata() {
  # create metadata file
  if [ -z $INPUT_KAGGLE_METADATA_PATH ]; then
    # check if the path is blank
    echo '{
      "id": "$INPUT_KERNEL_ID",
      "id_no": $INPUT_KERNEL_ID_no,
      "title": "$INPUT_KERNEL_TITLE",
      "code_file": "$INPUT_CODE_FILE_PATH",
      "language": "$INPUT_LANGUAGE",
      "kernel_type": "$INPUT_KERNEL_TYPE",
      "is_private": $INPUT_IS_PRIVATE,
      "enable_gpu": $INPUT_ENABLE_GPU,
      "enable_internet": $INPUT_ENABLE_INTERNET,
      "keywords": [$INPUT_KERNEL_KEYWORDS],
      "dataset_sources": [
        $INPUT_DATASET_SOURCES
      ],
      "kernel_sources": [
        $INPUT_KERNEL_SOURCES
      ],
      "competition_sources": [
        $INPUT_COMPETITION_SOURCES
      ]
    }' >kernel-metadata.json
    echo "The metadata file created"
  else
    if ! ls -d $INPUT_KAGGLE_METADATA_PATH > /dev/null 2>&1
      then
        mv $INPUT_KAGGLE_METADATA_PATH .
    fi
    echo "The metadata file already exist"
  fi
}

check_kernel_status_and_deploy() {
  KERNEL_STATUS=$(kaggle k status $INPUT_KERNEL_ID)
  if $?; then
    echo "The kernel is not found"
    exit 1
  fi
  if [[ "$KERNEL_STATUS" == *"has status \"complete\""* ]]; then
    echo "Kernel run is completed"
    deploy
  else
    echo "Kernel is still running..."
    exit 1
  fi
}

deploy() {
  output=$(kaggle k push)
  if $?; then
    echo "$output"
  else
    echo "There was an error while pushing the latest kernel"
    exit 1
  fi
}

submit_to_competition () {
  if [ -z $INPUT_SUBMITION_MESSAGE];then
    $INPUT_SUBMITION_MESSAGE=$(git log --no-merges -1 --oneline)
  fi
  kaggle c submit -f $INPUT_CODE_FILE_PATH -m $INPUT_SUBMITION_MESSAGE
}



# The step user follow:
# - There is case where the user is coming as a newbee
# - The newbee will create a python file or jupter file and then he tries to push his code

# - There will be person who will push the existing code
# - The existing code person should provide the meta and the login details.
# - He uploads his kernel and pushes the code

# - Check for the linting
# - So when he tries push we should check for the keys and the username, and we should show message for the event which is happening
# - The checks will be weather the username and password are correct
# - Is the push details provided as file or the args
# - Make a PR to make the meta file. $(this needs to be reconsidered)
# - Make a shedule to check action for the getting the current state
# - show success message
# - Save the output and the results from kaggle
# - Make a PR for saving the output file

# The things to collect:
# - They should enter the username and the key
# - They should make files or upload files
# - They should create the metadata file or update the metadata by args
# - Check if a version is running right now for the kernel
# - Submit the code while merging it to a new branch

# consider not needed but can do
# - The custom badge
# - The website to store all the results accuracy

# jupyter nbconvert test/*.ipynb --stdout --to script | flake8 - --ignore=W391
