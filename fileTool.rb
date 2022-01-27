require 'pathname'
require 'xcodeproj'
require_relative 'config'

module FileTool
  def self.find_dir(path, dic_name, should_create = false)
    result = path.children.collect do |child|
      # puts File.basename(child)
      if File.basename(child).eql?(dic_name)
        child
      end
    end.flatten.compact
    if result.empty? and should_create
      Dir.mkdir(path+dic_name)
    end
    result
  end

  def self.find_file(path, name, should_create = false)
    result = path.children.collect do |child|
      if child.file? && child.basename.eql?(name)
        child
      end
    end
    if result.empty? and should_create
      file = File.new(path+name, "w+")
      file.close
    end
    result
  end

  def self.find_file_with_ext(path, extname)
    result = path.children.collect do |child|
      if child.file? && child.extname.eql?(extname)
        child
      elsif child.directory?
          find_file_with_ext(child, extname)
      end
    end.flatten.compact
    result
  end
end

module FormatParsing
  def self.parsing_localized_string(string, strings_path)
    line_reg = "\"(.*?)\"\s*=\s*\"([\\s\\S]*?)(\";)$"
    match_res = string.match(line_reg)
    if match_res.nil?
      raise "解析国际化文件 #{strings_path} 失败"
    end
    hash_key = match_res[1].strip
    hash_value = match_res[2].strip
    return [hash_key, hash_value]
  end

  def self.remove_comments_and_empty(file_data)
    multiline_comments_regex = %r{/\*.*?\*/}m
    empty_lines_regex = /^[1-9]\d* $\n/
    file_data.gsub(multiline_comments_regex, '').gsub(empty_lines_regex, '') if file_data
  end

  def self.transform_str_value(str)
    value = "#{str}".strip
    # 去掉字符串前后空格
    if value.end_with?("\";") && value.start_with?("\"")
      value = value.delete_prefix('"').delete_suffix('";').strip
    end
    # 全角 % 与 边角 %
    value = value.gsub("\\n", "\n")
                 .gsub("\\\\", "\\")
                 .gsub("\\\"", "\"")
    pattern = /%\s*\d*(|@|s|S)/
    value = value.gsub(pattern, "%@")
    return value
  end
end

module XcodeTool
  def self.add_file_reference(language, group, group_path)
    file_ref = group.new_reference(group_path)
    file_ref.last_known_file_type = "text.plist.strings"
    file_ref.name = language
    file_ref.include_in_index = nil
  end

  def self.add_localize_language(language, projcet)
    known_regions = get_known_regions(projcet)
    unless known_regions.include?(language)
      # 设置known_regions
      known_regions << language
    end
  end

  def self.get_variant_group(project, strings_name)
    array = project.objects.select do |obj|
      obj.isa == "PBXVariantGroup" and obj.display_name == "#{strings_name}.strings"
    end
    array.first
  end

  def self.get_group(project)
    project.objects.each do |obj|
      if obj.isa == "PBXGroup"
        puts obj.real_path
      end
    end
  end

  def self.get_known_regions(project)
    known_regions = nil

    project.objects.each do |obj|
      if obj.isa == "PBXProject"
        known_regions = obj.known_regions
      end
    end
    known_regions
  end

end
