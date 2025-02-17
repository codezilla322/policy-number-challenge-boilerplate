module PolicyOcr
  DIGIT_MAP = {
    " _ | ||_|" => '0', "     |  |" => '1', " _  _||_ " => '2', " _  _| _|" => '3',
    "   |_|  |" => '4', " _ |_  _|" => '5', " _ |_ |_|" => '6', " _   |  |" => '7',
    " _ |_||_|" => '8', " _ |_| _|" => '9'
  }.freeze

  REVERSE_DIGIT_MAP = DIGIT_MAP.invert.freeze

  def self.parse_entry(entry_lines)
    return "Invalid entry" unless entry_lines.size == 4
    
    digits = (0..8).map do |i|
      digit_str = entry_lines[0][i*3,3] + entry_lines[1][i*3,3] + entry_lines[2][i*3,3]
      DIGIT_MAP[digit_str] || '?'
    end
    digits.join
  end

  def self.is_valid_checksum?(policy_number)
    return false unless policy_number.match?(/^\d{9}$/)
    sum = policy_number.chars.reverse.map(&:to_i).each_with_index.sum { |digit, idx| (idx + 1) * digit }
    sum % 11 == 0
  end

  def self.check_difference_count?(str1, str2)
    return false unless str1.length == str2.length
    diff_count = 0

    str1.each_char.with_index do |char, index|
      diff_count += 1 if char != str2[index]
      return false if diff_count > 1
    end

    diff_count == 1
  end

  def self.search_err_corrections(entry_lines)
    corrections = []
    policy = parse_entry(entry_lines)

    (0..8).each do |idx|
      ('0'..'9').each do |replacement|
        next if policy[idx] == replacement

        corrected = policy.dup
        policy_digit_str = REVERSE_DIGIT_MAP[policy[idx]]
        replacement_digit_str = REVERSE_DIGIT_MAP[replacement]

        if check_difference_count?(policy_digit_str, replacement_digit_str)
          corrected[idx] = replacement
        end

        if is_valid_checksum?(corrected)
          corrections << corrected
        end
      end
    end
    return corrections
  end

  def self.replace_question_marks(entry_lines, corrections, policy, idx)
    if policy.length == idx && is_valid_checksum?(policy)
      corrections << policy
    end

    if(policy[idx] == '?')
      policy_digit_str = entry_lines[0][idx*3,3] + entry_lines[1][idx*3,3] + entry_lines[2][idx*3,3]
      ('0'..'9').each do |replacement|
        replacement_digit_str = REVERSE_DIGIT_MAP[replacement]

        if check_difference_count?(policy_digit_str, replacement_digit_str)
          policy[idx] = replacement
          replace_question_marks(entry_lines, corrections, policy, idx + 1)
        end
      end
    elsif idx < policy.length
      replace_question_marks(entry_lines, corrections, policy, idx + 1)
    end
  end

  def self.search_ill_corrections(entry_lines)
    corrections = []
    policy = parse_entry(entry_lines)
    replace_question_marks(entry_lines, corrections, policy, 0)
    return corrections
  end

  def self.check_policy_number_file(input_file, output_file)
    results = File.foreach(input_file).each_slice(4).map do |entry_lines|
      policy = parse_entry(entry_lines)
      if policy.include?('?')
        corrections = search_ill_corrections(entry_lines)
        if corrections.size == 1
          corrections.first
        elsif corrections.empty?
          "#{policy} ILL"
        else
          "#{policy} AMB"
        end
      elsif is_valid_checksum?(policy)
        policy
      else
        corrections = search_err_corrections(entry_lines)
        if corrections.size == 1
          corrections.first
        elsif corrections.empty?
          "#{policy} ERR"
        else
          "#{policy} AMB"
        end
      end
    end

    File.open(output_file, 'w') do |file|
      results.each { |line| file.puts(line) }
    end
  end
end