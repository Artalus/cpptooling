---
layout: post
title: Publishing Jekyll blog on Github Pages via Travis CI
author: Artalus
tags: not-cpp blog
date: 2019-01-01 16:52:00 +03:00
tldr: >
    Writing Jekyll stuff is fun.
    But GitHub Pages do not support any Ruby programming.
    You have to integrate your static site repo with Travis CI and publish generated contents from there.
    ...And then you spend all your daylight hours trying to fix a single line
excerpt: >
    This is a short story about me trying to get this blog working on 1 January.
    Yeah, it is unrelated to C++ for approx. 99.9%.
    But it took so stupidly much time, I thought it might be worth to be immortalized here.
---

Writing Jekyll was kinda fun and unusual experience. The [official docs](https://jekyllrb.com/docs/) are okay, if a bit scarce. I advice to immediately copy your theme files from `~/.gem/ruby/2.5.0/gems/minima-2.5.0/{_includes,_layouts}` to your blog repo for the ease of modifying the default behavior.

Surprisingly, while being blog-aware, Jekyll (or rather, its default theme "minima") does not provide any means for displaying your posts tags, so I ended up combining [these](https://dev.to/rpalo/jekyll-tags-the-easy-way) [two](http://charliepark.org/tags-in-jekyll) solutions to generate list of tags for each post and a page listing all posts with this tag. A lot of duplicated code could be reduced by introducing custom [{`% tag %`}s](https://jekyllrb.com/docs/plugins/tags/) and [{`% include %`}s](https://jekyllrb.com/docs/includes/). Which, however, led to a small problem.

Turns out -- those "GitHub Pages do not support Jekyll plugins" I stumbled upon couple of times, meant not only third-party Jekyll-related Ruby (packages), but even 10-20 line Ruby snippets in `_plugins` folder that implement my custom tags like {`% taglist %`} or {`% tldr %`}! _"Outrageous!"_, thought I, and resorted to publishing the site via [Travis CI](https://travis-ci.org) service. Why Travis? Because I had some experience using it and it seemed to be best integrated with GitHub.

I quickly googled several solutions involving `bundle install; jekyll build; git checkout gh-pages; rm -rf; git push`, but the idea of completely automated publishing without any scripts was so prevalent, I finally stumbled upon [this beauty](https://medium.com/@mcred/supercharge-github-pages-with-jekyll-and-travis-ci-699bc0bde075):
{% highlight yaml %}
language: ruby
script:
- JEKYLL_ENV=production bundle exec jekyll build
env:
  global:
  # encrypted GH_TOKEN
  - secure: p9vtzE9II1 ...
branches:
  only:
  - master
deploy:
  provider: pages
  local-dir: "./_site"
  target-branch: gh-pages
  skip-cleanup: true
  github-token: "$GH_TOKEN"
  keep-history: true
  on:
    branch: master
{% endhighlight %}

I love when instead of bash script I can describe policy for doing stuff in declarative way. Don't you? So I happily put it into `.travis.yml`. It was about 11:30 AM.

I got very descriptive error message:
```
$ bundle install
Fetching gem metadata from https://rubygems.org/...........
Resolving dependencies...
Bundler could not find compatible versions for gem "safe_yaml":
  In Gemfile:
    jekyll (~> 3.8.4) was resolved to 3.8.5, which depends on safe_yaml (~> 1.0)
```
Since I saw Ruby for the first time last evening, it left me completely dumbfounded. Especially since, guess what? It works on my machine. And the gem (Ruby term for package) was actually present in repositories in more than one version, including the `1.0` mentioned and `1.0.4` installed locally.

Skipping the whole story, I tried switching Jekyll versions, Bundler versions, Ruby versions, Ruby virtual machines, updating everything Ruby-related that could be updated, updating everything in multiple ways... Then I gave up, created a separate repository consisting of `jenkins new .` and tried to publish it via Travis. It failed too!

I gave up one more time and went to Ruby chat in Telegram to ask _"WTF?"_. Wise Ruby gods had mercy on me and said, _"Remove Gemfile.lock from .gitignore"_.

...

What?.. But I did as was told, pushed changes to GH, and Travis installed everything correctly, and the example project was published and working.

So I voiced my concern, _"What?"_.

And the gods replied, _"Dunno lol `¯\_(ツ)_/¯`"_. And there was morning, and there was evening, about 15:30.

But doing this for my blog repo did nothing. So I wrote to Travis Support, frustrated a bit, gave up one more time and started comparing two projects symbol by symbol. Turned out, in my blog's `Gemfile` I had simply `gem "minima"`, while the example's `Gemfile` had `gem "minima", "~> 2.0"`. So I changed it in my `Gemfile`, and Travis installed everything correctly, and the blog was published. And there was evening, and there was even more evening, about 16:30.

...

So I voiced my concern one more time and went to writing this post and finished it in about an hour, or hour and half.

...

look, ma, im'ma blogier nau!
