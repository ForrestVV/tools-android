#!/bin/bash

cd `dirname $0`/..
export ROOT_DIR=`pwd`

. "${ROOT_DIR}"/env/sdkenv.sh

prepare_project () {
  PROJECT=$1
  REPO=$2
  TAG=$3

  cd "${SRCROOT}"

  if [ ! -d "${PROJECT}" ]; then
    if [ ${REPO##*.} = "gz" ]; then
      archive_name=`basename $REPO`
      echo -e "\n### Downloading project"
      curl -O -# ${REPO}
      echo -e "\n### Extracting project"
      mkdir ${PROJECT}
      tar -xzf ${archive_name} -C ${PROJECT} --strip-components 1
      rm -f ${archive_name}
    else
      echo -e "\n### Cloning project"
      git clone --recursive ${REPO} ${PROJECT}
    fi
  fi

  cd ${PROJECT}
  
  if [ -d .git ]; then

    if [ "$NO_CLEAN" != true ]; then
      echo -e "\n### Cleaning project"
      git reset --hard
      git clean -qfdx
    fi

    if [ "$NO_UPDATE" != true ]; then
      if [ -z $TAG ]; then
        # check if we should update project
        git_branch=`git symbolic-ref --short -q HEAD || echo "NONE"`
        if [ "$git_branch" != "NONE" ]; then
          # check if current branch has a remote
          git_remote=`git config --get branch.$git_branch.remote || echo "NONE"`
          if [ "$git_remote" != "NONE" ]; then
            echo -e "\n### Updating project"
            git pull
          else
            echo -e "\n### NOT updating project (no remote for branch $git_branch)"
          fi
        else
          echo -e "\n### NOT updating project (not on branch)"
        fi
      else
        echo -e "\n### Checking out $TAG"
        git fetch --tags
        git checkout -q $TAG
      fi

      git submodule sync --recursive
      git submodule update --recursive --init # also init in case submodule was added with update
    fi
    
  elif [ -f Makefile ]; then
    
    # no need to honor $NO_CLEAN here, as `make clean` doesn't reset any local changes
    echo -e "\n### Cleaning"
    make clean
    
  fi

  if [ "$NO_PATCHES" != true ]; then
    for patch in {"${ROOT_DIR}"/patches,${ADDITIONAL_PATCHES}}/${PROJECT}-*.patch; do
      if [ -f $patch ] ; then
        patch_name=`basename "$patch"`
        echo -e "\n### Applying $patch_name"
        patch -p1 --forward < "$patch" || [ $? -eq 1 ]
      fi
    done
  fi
  
  mkdir -p "${INSTALL_PREFIX}"
}
