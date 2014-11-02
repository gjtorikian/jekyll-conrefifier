require 'spec_helper'

describe("Integration Tests") do
  it "writes the proper page for simple substitutions" do
    expect(@dest.join("articles", "this-is-very-amazing", "index.html")).to exist
  end

  it "writes the proper page for compicated substitutions" do
    expect(@dest.join("articles", "welcome-to-github", "index.html")).to exist
  end

end
