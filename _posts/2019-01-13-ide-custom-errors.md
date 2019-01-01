---
layout: post
title:  "Custom errors in Qt Creator and Visual Studio"
author: Artalus
tldr: >
  If your tools produce output correlating to code lines and can be run from IDE (either as part of a general build or as a custom build target), consider formatting their output the same way as your compiler does. This way your IDE might be able to catch your tool's output and display it in its "Issues" section and/or link it to exact code lines.
excerpt: >
  Do you use tools that output errors related to the lines in your code? Can they be run from IDE? Then the chances are, your IDE might understand the output and link it to exact code lines.
image: /assets/ide-custom-errors/qt-err-tool-clang.png
tags: cmake qtcreator visualstudio ide
---

Modern IDEs have a nifty way to parse your build log output and gather a list of encountered errors. Take a look at Qt Creator's "Issues" output pane, for instance:

![]({{ "/assets/ide-custom-errors/qt-err.png" | relative_url }})

Here you can see a list of things Qt Creator decided to inform you about. Right now these are a product of GCC warning and error messages, that appear once I try to build the project.
This is how they look when `gcc` is invoked:
```
/usr/bin/g++    -Wall -MD -MT CMakeFiles/tool-output.dir/main.cpp.o -MF CMakeFiles/tool-output.dir/main.cpp.o.d -o CMakeFiles/tool-output.dir/main.cpp.o -c ../main.cpp
../main.cpp: In function ‘int main()’:
../main.cpp:11:1: error: expected initializer before ‘}’ token
 }
 ^
../main.cpp:6:6: warning: unused variable ‘y’ [-Wunused-variable]
  int y = x;
      ^
../main.cpp:9:6: warning: unused variable ‘z’ [-Wunused-variable]
  int z;
      ^
```

There is a pattern in those messages: `<file>[:line][:column]: [warning|error:] <message>`. You can imitate it to get  user-defined messages to appear in Issues pane too.

Let's create a new CMake project and add a file `test.sh` to its root:

{% highlight bash %}
#!/bin/bash
echo "./main.cpp:4: this might be an error in some compilers" 1>&2
echo "./main.cpp:5: error: this is an error" 1>&2
echo "./main.cpp:6: warning: this is a warning" 1>&2
echo "./main.cpp:7:10: warning: warning pointing to a symbol" 1>&2
echo "./main.cpp:8: note: maybe with a note to next line" 1>&2
exit 1
{% endhighlight %}

Notice the output redirection from `stdout` (stream `1`) to `stderr` (stream `2`). While Qt Creator will display any output in its Compile Output pane, only messages from `stderr` will be parsed and put into Issues. Exit code is not necessary, but will be used by Qt Creator to abort build process if not zero.

Let's check this out on a CMake project. The structure should be like this:
```
tool-output/
├── CMakeLists.txt
├── main.cpp
└── test.sh
```

Open the project in Qt Creator, go to "Projects" mode and add a new Build Configuration "tool-gcc" with a single Custom Build step to run `./test.sh` script:

![]({{ "/assets/ide-custom-errors/qt-buildconf.png" | relative_url }})

It will appear in build selection menu:

![]({{ "/assets/ide-custom-errors/qt-build.png" | relative_url }})

And if you "build" your project with it, you can see new issues appear in the list:

![]({{ "/assets/ide-custom-errors/qt-err-tool.png" | relative_url }})

Notice that only the second message is treated as error with red indicator, while the first and the last one are displayed as simple messages. This seems to happen because I used GCC in my "Default" kit. If I switch to another kit using Clang as a compiler, I get slightly different results:

![]({{ "/assets/ide-custom-errors/qt-err-tool-clang.png" | relative_url }})

Here both messages #1 and #2 are displayed as errors, while message #5 is treated as a description of sort for #4. Opening "Compile Output" pane you can see the "build" log:
```
20:54:57: Running steps for project tool-output...
20:54:57: Starting: "/home/artalus/tool-output/test.sh"
./main.cpp:4: this might be an error in some compilers
./main.cpp:5: error: this is an error
./main.cpp:6: warning: this is a warning
./main.cpp:7:10: warning: warning pointing to a symbol
./main.cpp:8: note: maybe with a note to next line
20:54:57: The process "/home/artalus/tool-output/test.sh" exited with code 1.
Error while building/deploying project tool-output (kit: Clang lc++)
When executing step "Custom Process Step"
20:54:57: Elapsed time: 00:00.
```

But why use a custom build step in Qt project when we already have CMake? For example, we can execute our "tool" as a `POST_BUILD` target command by adding this to `CMakeLists.txt`:

{% highlight cmake %}
add_executable(tool-output "main.cpp")
add_custom_command(
    TARGET tool-output POST_BUILD
    COMMAND bash ${CMAKE_SOURCE_DIR}/test.sh
)
{% endhighlight %}

Now building the project with `cmake --build .` will automatically cause the "tool" to run after building the executable, displaying same messages as before. And in Qt Creator they will still appear in the "Issues" pane.

The format for compiler messages in Visual Studio would be different:

```
P:\tool\main.cpp(6,11): warning C4244: 'initializing': conversion from '__int64' to 'int', possible loss of data
P:\tool\main.cpp(11): error C2143: syntax error: missing ';' before '}'
```

So let's change our script:
{% highlight bash %}
#!/bin/bash
echo "./main.cpp(4): this will be ignored " 1>&2
echo "./main.cpp(4): error: this might be an error " 1>&2
echo "./main.cpp(5): error Z1337: this is an error" 1>&2
echo "./main.cpp(6): warning X1338: this is a warning" 1>&2
echo "./main.cpp(7,10): warning: warning pointing to a symbol" 1>&2
echo "./main.cpp(8): note: maybe with a note to next line" 1>&2
exit 1
{% endhighlight %}

This will produce nice output in "Error List" pane of Visual Studio. Note however that while VS provides error codes to distinguish messages, it ignores messages that do not contain `warning:` or `error:` altogether.

![]({{ "/assets/ide-custom-errors/vs-err-tool.png" | relative_url }})

If this is a too syntetic example for you, here is more useful one. Let's use [Catch2](https://github.com/catchorg/Catch2/blob/master/docs/tutorial.md) library to write a unit-test:
{% highlight cpp %}
#define CATCH_CONFIG_MAIN
#include <catch.hpp>

TEST_CASE("test case") {
	REQUIRE(1 == 0);
}
{% endhighlight %}

and run it in our `tool.sh`:

{% highlight bash %}
#!/bin/bash
./tool-output # './', since it will be launched from build directory
{% endhighlight %}

Catch2 outputs the problem line if the test fails:
```
/home/artalus/main.cpp(5): FAILED:
  REQUIRE( 1 == 0 )
```

Which in Qt Creator will nicely result in a valid pointer to exact line (but won't mention fail reason, unfortunately):

![]({{ "/assets/ide-custom-errors/qt-err-catch.png" | relative_url }})

With Visual Studio, however, I had to hack the error message in `ConsoleAssertionPrinter` class from simply `"FAILED"` to `"error C1337: TEST CASE FAILED"` to achieve this behavior:

![]({{ "/assets/ide-custom-errors/vs-err-catch.png" | relative_url }})

The Catch2 example was actually something I've noticed accidentally, that gave me idea to write this note (and eventually lead to a decision to start this blog). But here is a real-world example.

In our work project we have CppCheck wrapper script that can be run as Jenkins job, as commit-check in Mercurial, and as a separate build target. It allows user to define message formatting and provides two default options - VS-compatible and Qt Creator compatible ones. Thus by simply building a "cppcheck" target, the developer can immediately see the check results and navigate around them in their IDE of choice. Here are its output examples from the lightning talk I gave at work last summer:

![]({{ "/assets/ide-custom-errors/cppcheck-term.png" | relative_url }})

![]({{ "/assets/ide-custom-errors/cppcheck-qt.png" | relative_url }})
