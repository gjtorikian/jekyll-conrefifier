require 'spec_helper'

describe("Conrefifier") do
  it "writes the proper page for simple substitutions" do
    expect(@dest.join("articles", "p-this-is-very-amazing-p", "index.html")).to exist
  end

  it "writes the proper page for compicated substitutions" do
    expect(@dest.join("articles", "p-welcome-to-github-p", "index.html")).to exist
  end

  it "writes the proper content for values after fetching info from a data file" do
    index_file = @dest.join("index.html")
    expect(index_file).to exist
    index_contents = File.read(index_file)
    expect(index_contents).to include("GitHub Glossary")
  end

  it "writes the proper content for keys after fetching info from a data file" do
    index_file = @dest.join("index.html")
    expect(index_file).to exist
    index_contents = File.read(index_file)
    expect(index_contents).to include("<a href=\"/categories/amazing\">Amazing</a>")
  end

  it "writes the proper content for values with Markdown" do
    index_file = @dest.join("articles", "p-this-is-strong-wow-strong-p", "index.html")
    expect(index_file).to exist
    index_contents = File.read(index_file)
    expect(index_contents).to include("<strong>wow!</strong>")
  end
end
