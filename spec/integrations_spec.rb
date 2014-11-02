require 'spec_helper'

describe("Integration Tests") do
  it "writes the redirect pages for collection items which are outputted" do
    expect(@dest.join("articles", "filtered_frontmatter.html")).to exist
  end

  it "doesn't write redirect pages for collection items which are not outputted" do
    expect(@dest.join("authors")).not_to exist
    expect(@dest.join("kansaichris")).not_to exist
  end
end
