---
layout: post
title:  'Conan: speed up Travis builds with cache'
author: Artalus
tldr: >
  When building Conan packages in cloud CI's, cache might be your best friend. Preserving `conan/.data` directory between CI runs and mounting it into Docker builders can speed your builds up to several times.
image: #/assets/ide-custom-errors/qt-err-tool-clang.png
tags: conan ci travis
---

[Travis](https://travis-ci.org) is a cool cloud-hosted CI service, perfectly integrated with GitHub. It is also widely used in [Conan](https://conan.io) community to automatically build, pack and upload open source packages. However, based in cloud means it ultimately runs a fresh virtual machine instance for each of your builds. Thus, Conan will have to pull them all (and sometimes build) every time before building the actual package - which would be almost a no-op otherwise. Thankfully, there is a way to avoid repeating this step on each VM restart.

In the most simple workflow, you specify a build matrix like this in `.travis.yml`:
```yaml
  - <<: *osx
    osx_image: xcode10
    env: CONAN_APPLE_CLANG_VERSIONS=10.0
  - <<: *linux
    env: CONAN_GCC_VERSIONS=4.9 CONAN_DOCKER_IMAGE=conanio/gcc49
  - <<: *linux
    env: CONAN_CLANG_VERSIONS=6.0 CONAN_DOCKER_IMAGE=conanio/clang60
```
For each matrix entry Travis runs a `build.py` script with contents like this:
```python
from cpt.packager import ConanMultiPackager
builder = ConanMultiPackager()
builder.add_common_builds()
builder.run()
```
[Conan Package Tools](https://github.com/conan-io/conan-package-tools) will look for a set of specific environment variables, pull a Docker image (if it is specified) with a specified compiler and run several builds inside this image.

So here is my library:
```cmake
# CMakeLists.txt
cmake_minimum_required(VERSION 2.8)
project(Sometimes CXX)
include(${CMAKE_BINARY_DIR}/conanbuildinfo.cmake)
conan_basic_setup(TARGETS)
add_library(sometimes sometimes.cpp)
target_link_libraries(sometimes CONAN_PKG::boost_date_time)
```
```cpp
// sometimes.cpp
#include <iostream>
#include <boost/date_time/gregorian/gregorian.hpp>

void sometimes(){
    using namespace boost::gregorian;
    date today = day_clock::local_day();
    partial_date new_years_day(1,Jan);
    days days_since_year_start = today - new_years_day.get_date(today.year());
    std::cout << "Days since Jan 1: " << days_since_year_start.days() << endl;
}
```
Here are typical build matrices for a single compiler build:
```
+-------------+--------+--------------------+--------------+
| compiler    | arch   |   compiler.version | build_type   |
|-------------+--------+--------------------+--------------|
| gcc         | x86    |                  7 | Release      |
| gcc         | x86    |                  7 | Debug        |
| gcc         | x86_64 |                  7 | Release      |
| gcc         | x86_64 |                  7 | Debug        |
+-------------+--------+--------------------+--------------+
| compiler    | arch   |   compiler.version | build_type   |
+-------------|--------+--------------------+--------------|
| apple-clang | x86_64 |                9.1 | Release      |
| apple-clang | x86_64 |                9.1 | Debug        |
+-------------+--------+--------------------+--------------+
```

And here are build times:

{% img before.png %}

That's kinda uncool for a library containing a single function and a single dependency from [Modular Boost](https://bincrafters.github.io/2017/10/11/Conan-Package-Boost-1-65-1/) (let's forget that Datetime depends on a dozen other Boost libraries ;) ). What's happening is that during each CI run the library is built twice (Debug/Release), and then twice again (x86/x64) for Linux builds. And there are three independent problems occuring:
- on Linux the packages are redownloaded during each compiler run in Docker
- once downloaded, the packages will be wiped when next Travis build is triggered
- on MacOS install step takes ridiculously long

## Caching Conan

This one is relatively easy. Travis provides us with [directory caching](https://docs.travis-ci.com/user/caching/) mechanism, so first of all we can add this to our `.travis.yml`:
```yaml
linux: &linux
  ...
  cache:
    directories:
      - $HOME/.conan/data
osx: &osx
  ...
  cache:
    directories:
      - $HOME/.conan/data
```
This won't help immediately with Linux builds however, because Conan is run within Docker there. It means that although `data` directory is indeed cached between different build runs, it is invisible for Conan run inside Docker. To address this I made a [simple change in CPT](https://github.com/conan-io/conan-package-tools/pull/343) that allows passing user-specified parameters to Docker when `conan create` step is run.

If you create your packager like this:
```python
    packager = ConanMultiPackager(
        docker_build_options='--mount type=bind,source=$HOME/.conan/data,destination=/home/conan/.conan/data',
```
then dependencies inside docker will be downloaded into directory from the parent system. Thus, they will be preserved by Travis cache between runs winning us some time saving us the time to download all package archives (and build them if you are unlucky).

You should also consider running something like `rm -rf $HOME/.conan/data/<your_package>` at `before_cache` step in Travis. You are building the package anew each time any way, so why bother caching it at all?

## Caching MacOS prerequisites

This one is kinda tricky.

I did a test run for a single MacOS image with only the install step, and running the build took **about 11 minutes**, which were spent like this:
 - **5m** to perform `brew update`
 - **1m45s** to upgrade pyenv (by also upgrading to fresh OpenSSL)
 - **3m** to install needed Python version into pyenv
 - **40s** to install Conan and CPT from pip

(All timings were done in `xcode9.3` image, but total build times were close enough for `8.3` and `10` too.)

The easiest thing is to `export HOMEBREW_NO_AUTO_UPDATE=1` and omit `brew update` step at all. This will skip 5m of Homebrew updating itself + ~1m30s of upgrading OpenSSL for pyenv, but you will have to deal with rather old versions of packages.
After this, install took me **4m27s**.

Next we can speed up pyenv. Downloading Python is not a problem - most time goes to installing it. So I cached `~/.pyenv/versions/2.7.10` - this preserves both Python itself and pip packages installed for it. I also had to call `pyenv install` with `--skip-existing` and `pyenv virtualenv` with `--force`.

Now install takes **1m30s**, and I also have **~40 MB** of cached data in Travis.

{% note %}
Depending on your setup you may encounter problems with pip package files being cached inconsistently. You might want to use `pip install --force-reinstall` or just remove `lib/python2.7/site-packages/*.dist-info` during `before_cache`.
{% endnote %}

If you are okay with old Homebrew packages - then here you have the fastest install step configuration. However in many cases you might need latest version of CMake or some other tool, so it would be nice to still have `brew update` - if only it didn't take those painful minutes to run!

So I found [this SO answer](https://stackoverflow.com/a/53331571/5232529) that I advice you to read carefully. In essence, you should cache `/usr/local/Homebrew`, since there lies an updated Homebrew, but cleanup its subdirectories a bit before running `brew update` - namely remove `/usr/local/Homebrew/Library/Taps/caskroom/homebrew-cask` if `/usr/local/Homebrew/Library/Taps/homebrew/homebrew-cask` is present and run `git clean -fxd` on any git repo inside `/usr/local/Homebrew`.
After this, install takes **2m30s** and cache bloats up to **~330 MB**, but you gain access to the latest versions of Homebrew packages.

---

Summing up! We have something like this in your `.travis.yml`:
```yaml
linux: &linux
  os: linux
  dist: xenial
  sudo: required
  language: python
  python: "3.6"
  services:
    - docker
  cache:
    directories:
      - $HOME/.conan/data
osx: &osx
  os: osx
  language: generic
  cache:
    directories:
      - $HOME/.conan/data
      - $HOME/.pyenv/versions/2.7.10/
      - /usr/local/Homebrew
```

MacOS part of our `.travis/install.sh` will look like this:
```bash
if [[ "`uname -s`" == 'Darwin' ]]; then
    curdir=`pwd`
    cd /usr/local/Homebrew/
    if [[ -d Library/Taps/homebrew/homebrew-cask ]]; then
        rm -rf Library/Taps/caskroom/homebrew-cask
    fi
    for d in `find $(pwd) -type d -name .git`; do
        cd `dirname $d`
        git clean -fxd
    done
    brew cleanup
    cd $curdir

    brew update
    brew outdated pyenv || brew upgrade pyenv
    brew install pyenv-virtualenv
    brew install cmake || true

    if which pyenv > /dev/null; then
        eval "$(pyenv init -)"
    fi

    pyenv install 2.7.10 --skip-existing
    pyenv virtualenv 2.7.10 conan --force
    pyenv rehash
    pyenv activate conan
fi
```

And finally, in our build-script we create packager with additional arguments to pass to Docker:
```python
packager = ConanMultiPackager(
  docker_build_options='--mount type=bind,source=$HOME/.conan/data,destination=/home/conan/.conan/data',
)
packager.add_common_builds()
```

How did it change our build times?

{% img middle.png %}

This is right after activating caches and running Docker with mounted `data` directory. Notice the immediate effect on Linux builds that now utilize the fact that some dependencies (like header-only libs) stay the same even between x86/x84 and Debug/Release builds!

{% img after.png %}

And this is the next CI run after the caches were populated. MacOS builds went from  12min down to 4min, and Linux ones from 9min down to 2min. This might not seem like a big deal, but I've seen builds taking up to a hour, where most of that time (and log space) were spent on rebuilding things due to building unpopular packages with unpopular compiler settings.

This trade-off will also become greater when you have a lot of dependencies and/or additional parameters affecting the combinatorial explosion of build matrix, be it a variety of `options` or compilers.

# What about Appveyor?

Appveyor too have [build cache](https://www.appveyor.com/docs/build-cache/), but bear in mind that there is a `[1GB for free plan] hard quota which means the build will fail while trying to upload cache item exceeding the quota.`

Logic stays almost the same: you cache `'%USERPROFILE%\.conan\data'` (mind the quotes!), and you might also want to cache `C:\.conan` if you encounter the [`short_paths`](https://docs.conan.io/en/latest/reference/conanfile/attributes.html#short-paths) problems (see [this](https://cpplang.slack.com/archives/C77T8CBFB/p1520795953000093) discussion for additional info).

Unfortunately, I could not get cache to give same speed up as it was with Linux builds.

In my tests I had a build matrix like this:
```
+------------------+---------------+--------+------------+------------------+
| compiler.version | compiler      | arch   | build_type | compiler.runtime |
|------------------+---------------+--------+------------+------------------|
|               14 | Visual Studio | x86    | Release    | MT               |
|               14 | Visual Studio | x86    | Release    | MD               |
|               14 | Visual Studio | x86    | Debug      | MTd              |
|               14 | Visual Studio | x86    | Debug      | MDd              |
|               14 | Visual Studio | x86_64 | Release    | MT               |
|               14 | Visual Studio | x86_64 | Release    | MD               |
|               14 | Visual Studio | x86_64 | Debug      | MTd              |
|               14 | Visual Studio | x86_64 | Debug      | MDd              |
+------------------+---------------+--------+------------+------------------+
```
and managed to get build time only from 15 minutes down to 8. While it is still a nice trade-off, I believe it could become even better If I were to experiment with Appveyor long enough.
