require_relative '../lib/policy_ocr'

describe PolicyOcr do
  it "loads" do
    expect(PolicyOcr).to be_a Module
  end

  it "loads the sample.txt" do
    expect(fixture("sample").lines.count).to eq(44)
  end

  describe ".parse_entry" do 
    it "correctly parses a valid entry" do 
      entry_lines = [
        " _  _  _  _  _  _  _  _  _ ",
        "| || || || || || || || || |",
        "|_||_||_||_||_||_||_||_||_|",
        "                           "
      ]
      expect(PolicyOcr.parse_entry(entry_lines)).to eq("000000000")
    end

    it "handles entries with illegible characters" do 
      entry_lines = [
        " _  _     _  _  _  _  _  _ ",
        "| || |   | || || || || || |",
        "|_||_|  ||_||_||_||_||_||_|",
        "                           "
      ]
      expect(PolicyOcr.parse_entry(entry_lines)).to eq("00?000000")
    end

    it "returns 'Invalid entry' for entries with incorrect number of lines" do 
      entry_lines = [
        " _  _  _  _  _  _  _  _  _ ",
        "| || || || || || || || || |",
        "|_||_||_||_||_||_||_||_||_|"
      ]
      expect(PolicyOcr.parse_entry(entry_lines)).to eq("Invalid entry")
    end
  end

  describe ".is_valid_checksum?" do 
    it "returns true for valid policy numbers" do 
      expect(PolicyOcr.is_valid_checksum?("345882865")).to be true
    end

    it "returns false for invalid policy numbers" do
      expect(PolicyOcr.is_valid_checksum?("A234B6789")).to be false
    end

    it "returns false for policy numbers with incorrect format" do
      expect(PolicyOcr.is_valid_checksum?("12345678X")).to be false
      expect(PolicyOcr.is_valid_checksum?("123456")).to be false
    end
  end

  describe ".check_difference_count?" do
    it "returns true when strings differ by exactly one character" do
      expect(PolicyOcr.check_difference_count?("abc", "abd")).to be true
    end

    it "returns false when strings differ by more than one character" do
      expect(PolicyOcr.check_difference_count?("abc", "def")).to be false
    end

    it "returns false when strings are identical" do
      expect(PolicyOcr.check_difference_count?("abc", "abc")).to be false
    end

    it "returns false when strings have different lengths" do
      expect(PolicyOcr.check_difference_count?("abc", "abcd")).to be false
    end
  end

  describe ".check_policy_number_file" do
    before do
      # Set up test files
      @input_file = "test_input.txt"
      @output_file = "test_output.txt"
    end

    after do
      # Clean up test files
      File.delete(@input_file) if File.exist?(@input_file)
      File.delete(@output_file) if File.exist?(@output_file)
    end

    it "correctly processes entries that can be corrected" do
      # Entry that can be corrected from 000000051 to 000000057
      File.open(@input_file, "w") do |file|
        file.puts(" _  _  _  _  _  _  _  _    ")
        file.puts("| || || || || || || ||_   |")
        file.puts("|_||_||_||_||_||_||_| _|  |")
        file.puts("                           ")
      end

      PolicyOcr.check_policy_number_file(@input_file, @output_file)
      
      output = File.readlines(@output_file).map(&:chomp)
      expect(output[0]).not_to include(" ERR")
    end

    it "correctly marks ambiguous entries" do
      
      allow(PolicyOcr).to receive(:parse_entry).and_return("123456789")
      allow(PolicyOcr).to receive(:is_valid_checksum?).and_return(false)
      allow(PolicyOcr).to receive(:search_err_corrections).and_return(["123456781", "123456782"])
      
      File.open(@input_file, 'w') do |file|
        file.puts("mock entry line 1")
        file.puts("mock entry line 2")
        file.puts("mock entry line 3")
        file.puts("mock entry line 4")
      end

      PolicyOcr.check_policy_number_file(@input_file, @output_file)
      
      output = File.readlines(@output_file).map(&:chomp)
      expect(output[0]).to eq("123456789 AMB")
    end
  end
end
