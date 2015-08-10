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

Note that Markdown rendering is enabled for this content.

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

## Liquid filtering within data files

You can add filters within data files, to show or hide content depending on certain variable criteria.

For example, given a data file that looks like this:

``` yaml
Listing:
  {% if page.version == '2.0' %}
  - Article v2.0
  {% endif %}
  {% if page.version != '2.0' %}
  - Article v2.1
  {% endif %}

{% unless page.version == '2.0' %}
Ignored:
  - Item1
  - Item 2
{% endunless %}
```

If `page.version` is equal to `'2.0'`, only `Listing: - Artivle v2.0` will render.

To support such a syntax, you'll need to add a new entry in your `config.yml` that defines your variables, like this:

``` yaml

data_file_variables:
  -
    scope:
      path: ""
    values:
      version: "2.0"

```

`data_file_variables` is an array of hashes. The `scope` key defines which data files are affected by the variables; the data file must match the path define in `path`. Regular expression syntaxes are supported in `path`, and a blank `path` refers to every data file. The `values` key specifies every key you want to support in your data file.

Here's a more complex example:

``` yaml
data_file_variables:
  -
    scope:
      path: ""
    values:
      version: "2.0"
  -
    scope:
      path: "ent\\w+_"
    values:
      version: "2.1"

```

In this case, every data file has a `page.version` of `2.0`. However, only data files prefixed with `ent`, containing one or more word characters (`\w+`), and followed by an underscore (`_`), have a value of `2.1`.

## Rendering filtered data files in layouts

As an addition to the above, a new tag, `data_render`, can be used to iterate over filtered data files.

You can call this filter by:

* Passing a data file name to `data_render`
* Passing any optional variables to this filter
* The YAML information will be temporarily stored within `site.data.data_render`
* You can iterate over `site.data.data_render` to walk along the data
* Multiple calls to `data_render` rewrite to `site.data.data_render`

Here's an example:

``` liquid
{% data_render site.data.filtered_categories(:version => 2.0.to_s) %}

{% for category_hash in site.data.data_render %}
  {% assign category_title    = category_hash[0] %}
  {% assign category_articles = category_hash[1] %}
  {{ category_title }}
  {{ category_articles }}
{% endfor %}
```

Note that data files are read *once*, to improve performance. The variables passed in are evaluated for each call.
