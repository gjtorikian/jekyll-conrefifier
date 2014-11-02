# jekyll-conrefifier

A set of monkey patches that allows you to use Liquid variables in a variety of places in Jekyll.

## Substitutions within frontmatter

You can include Liquid variables in your frontmatter, like this:

``` markdown
---
title: This is very {{ site.data.conrefs.product_type }}
---

Some page.
```

In this case, title would equals the value of `product_type` in [a data file](http://jekyllrb.com/docs/datafiles/) called *conrefs*.

## Per-audience filtering

You can scope your variables to an audience value. For example, given a conref file that looks like this:

``` yaml
product_name:
  dotcom: GitHub
  2.0: GitHub Enterprise
  11.10.340: GitHub Enterprise
```

And a file that looks like this:

``` markdown
---
title: Welcome to {{ site.data.conrefs.product_name[site.audience] }}
---

Some other page.
```

The title renders through `product_name`, then the value of `site.audience` to become "Welcome to GitHub".

## Substitutions within data files

Your data files can also rely on Liquid substitution. For example, given a data file called *categories.yml* that looks like this:

``` yaml
Bootcamp:
  - Set Up Git
  - Create A Repo
  - Fork A Repo
  - Be Social
  - '{{ site.data.conrefs.product_name[site.audience] }} Glossary'
  - Good Resources for Learning Git and GitHub
```

The value renders out to "GitHub Glossary", just like above.
