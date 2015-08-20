require 'spec_helper'

describe("Conrefifier") do
  it "writes the proper page for simple substitutions" do
    expect(@dest.join("articles", "this-is-very-amazing", "index.html")).to exist
  end

  it "writes the proper page for compicated substitutions" do
    expect(@dest.join("articles", "welcome-to-github", "index.html")).to exist
  end

  it "writes the proper content for values after fetching info from a data file" do
    index_file = @dest.join('index.html')
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
    index_file = @dest.join("articles", "this-is-strong-wow-strong", "index.html")
    expect(index_file).to exist
    index_contents = File.read(index_file)
    expect(index_contents).to include("<strong>wow!</strong>")
  end

  it 'filters simple items' do
    filtered_index_file = @dest.join("filtered_index.html")
    expect(filtered_index_file).to exist
    filtered_index_contents = File.read(filtered_index_file)
    expect(filtered_index_contents).to include("GitHub Enterprise Glossary")
    expect(filtered_index_contents).to include("Fork A Repo")
    expect(filtered_index_contents).to include("Article v2.0")
    expect(filtered_index_contents).to include("Still show")
    expect(filtered_index_contents).to_not include("Article v2.1")
    expect(filtered_index_contents).to_not include("Ignored")
  end

  it 'filters items when a prefix is provided' do
    enterprise_filtered_index = @dest.join("enterprise_filtered_index.html")
    expect(enterprise_filtered_index).to exist
    filtered_index_contents = File.read(enterprise_filtered_index)
    expect(filtered_index_contents).to include("GitHub Enterprise Glossary")
    expect(filtered_index_contents).to include("Fork A Repo")
    expect(filtered_index_contents).to include("Article v2.1")
    expect(filtered_index_contents).to include("Still show")
    expect(filtered_index_contents).to_not include("Article v2.0")
    expect(filtered_index_contents).to_not include("Ignored")
  end

  it 'uses the data_render tag to provide filtered data in a layout' do
    filtering_layout = @dest.join("filtering_layout.html")
    expect(filtering_layout).to exist
    filtering_layout_contents = File.read(filtering_layout)
    expect(filtering_layout_contents).to include('GitHub Enterprise Glossary')
    expect(filtering_layout_contents.scan(/Bootcamp/).count).to eq(2)
    expect(filtering_layout_contents.scan(/Article v2.1/).count).to eq(1)
    expect(filtering_layout_contents.scan(/Article v2.0/).count).to eq(1)
    expect(filtering_layout_contents.scan(/Ignored/).count).to eq(1)
  end
end
