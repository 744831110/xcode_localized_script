require 'pathname'
require 'xcodeproj'
require_relative 'config'

module FileTool
  def self.findDir(path, dicName, should_create = false)
    result = path.children.collect do |child|
      # puts File.basename(child)
      if File.basename(child).eql?(dicName)
        child
      elsif child.directory?
        findDir(child, dicName)
      end
    end.flatten.compact
    if result.empty? and should_create
      Dir.mkdir(path+dicName)
    end
    result
  end

  def self.findFileWithExtname(path, extname)
    path.children.collect do |child|
      if child.file? && File.extname(child).end_with?(extname)
        child
      elsif child.directory?
        findFileWithExtname(child, extname)
      end
    end.flatten.compact
  end

  def self.findFileWithName(path, name, should_create = false)
    result = path.children.collect do |child|
      if child.file? && child.basename.eql?(name)
        child
      elsif child.directory?
        findFileWithName(child, extname)
      end
    end.flatten.compact
    if result.empty? and should_create
      file = File.new(path+name, "w+")
      file.close
    end
    result
  end
end

module FormatParsing
  def self.parsingLocalizedString(string)
    line_reg = "\"(.*?)\"\s*=\s*\"([\\s\\S]*?)(\";)$"
    match_res = str.match(line_reg)
    if match_res.nil?
      raise "解析国际化文件 #{strings_path} 失败"
    end
    hash_key = match_res[1].strip
    hash_value = match_res[2].strip
    return [hash_key, hash_value]
  end

  def self.remove_comments_and_empty_lines(file_data)
    multiline_comments_regex = %r{/\*.*?\*/}m
    empty_lines_regex = /^[1-9]\d* $\n/
    file_data.gsub(multiline_comments_regex, '').gsub(empty_lines_regex, '') if file_data
  end
end

module XcodeTool
  def self.addFileReference(language, group, group_path)
    file_ref = group.new_reference(group_path)
    file_ref.last_known_file_type = "text.plist.strings"
    file_ref.name = language
    file_ref.include_in_index = nil
    # project.targets.first.add_resources([file_ref])
  end

  def self.addLocalizeLanguage(language, projcet)
    known_regions = getKnownRegions(projcet)
    unless known_regions.include?(language)
      # 设置known_regions
      known_regions << language
    end
  end

  def self.getVariantGroup(project, stringsName)
    array = project.objects.select do |obj|
      obj.isa == "PBXVariantGroup" and obj.display_name == "#{stringsName}.strings"
    end
    array.first
  end

  def self.getGroup(project)
    project.objects.each do |obj|
      if obj.isa == "PBXGroup"
        puts obj.real_path
      end
    end
  end

  def self.getKnownRegions(project)
    known_regions = nil

    project.objects.each do |obj|
      if obj.isa == "PBXProject"
        known_regions = obj.known_regions
      end
    end
    known_regions
  end

end
