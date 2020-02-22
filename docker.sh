#!/usr/bin/env bash

export CMAKE_VERSION="3.15.2"

main() {
  if [[ -z "${run_build_script}" ]] ; then
    startDockerContainer || return 1
  else
    buildOsqueryToolchain || return 1
  fi

  return 0
}

startDockerContainer() {
  if [[ -d "build" ]] ; then
    echo "Reusing existing build folder"
  else
    echo "Creating new build folder"

    mkdir build
    if [[ $? != 0 ]] ; then
      echo "Failed to create the build folder"
      return 1
    fi
  fi

  local container_name="osquery-toolchain-$(git rev-parse HEAD)"
  docker rm "${container_name}" > /dev/null 2>&1

  docker run --rm -e "run_build_script=1" -v "$(realpath build):/opt/osquery-toolchain" -v "$(pwd):/home/osquery/osquery-toolchain" --name "${container_name}" -it ubuntu /bin/bash -c '/home/osquery/osquery-toolchain/docker.sh'
  if [[ $? != 0 ]] ; then
    echo "Failed to start the Docker container"
    return 1
  fi

  return 0
}

buildOsqueryToolchain() {
  # https://stackoverflow.com/questions/59895/how-to-get-the-source-directory-of-a-bash-script-from-within-the-script-itself
  local home_folder="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
  cd "${home_folder}"

  installSystemDependencies || return 1
  installCMake || return 1
  initializeOsqueryUser || return 1

  export KEEP_INTERMEDIATE_STAGES=1
  sudo -u osquery ./build.sh "/opt/osquery-toolchain"
  if [[ $? != 0 ]] ; then
    echo "The build script has failed"
    return 1
  fi

  return 0
}

initializeOsqueryUser() {
  useradd -d "/home/osquery" -M osquery
  if [[ $? != 0 ]] ; then
    echo "Failed to create the osquery user"
    return 1
  fi

  chown -R osquery:osquery "/home/osquery"
  if [[ $? != 0 ]] ; then
    echo "Failed to set the require permissions on the home directory"
    return 1
  fi

  return 0
}

installSystemDependencies() {
  apt-get update
  if [[ $? != 0 ]] ; then
    echo "Failed to update the package repositories"
    return 1
  fi

  apt-get install g++-8 gcc-8 automake autoconf gettext bison flex unzip help2man libtool-bin libncurses-dev make ninja-build wget git texinfo xz-utils gawk python sudo -y
  if [[ $? != 0 ]] ; then
    echo "Failed to install the required dependencies"
    return 1
  fi

  update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-8 20
  if [ $? != 0 ] ; then
    echo "Failed to set the default gcc binary path"
    return 1
  fi

  update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-8 20
  if [ $? != 0 ] ; then
    echo "Failed to set the default g++ binary path"
    return 1
  fi

  update-alternatives --install /usr/bin/cpp cpp /usr/bin/cpp-8 20
  if [ $? != 0 ] ; then
    echo "Failed to set the default cpp binary path"
    return 1
  fi

  return 0
}

installCMake() {
  local cmake_archive_path="/tmp/cmake.tar.gz"
  wget "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-Linux-x86_64.tar.gz" -O "${cmake_archive_path}"
  if [[ $? != 0 ]] ; then
    echo "Failed to download the CMake release archive"
    return 1
  fi

  tar xvf "${cmake_archive_path}" -C "/usr/local" --strip 1
  if [[ $? != 0 ]] ; then
    echo "Failed to extract the CMake release archive"
    return 1
  fi

  return 0
}

main $@
exit $?
