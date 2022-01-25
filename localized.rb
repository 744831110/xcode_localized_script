require 'roo'
require 'pathname'
require 'xcodeproj'
require_relative 'fileTool'
require_relative 'config'

module Localized

  class LocalizedData
    attr_accessor :localized_key
    attr_accessor :language_hash

    def initialize
      self.language_hash = Hash.new
    end

    def [](language)
      if LANGUAGE.include?(language)
        self.language_hash[language]
      end
    end

    def []=(language, value)
      if LANGUAGE.include?(language)
        self.language_hash[language] = FormatParsing.transform_str_value(value)
      end
    end

    def get_localized_for_language(language)
       "\"#{localized_key}\" = \"#{language_hash[language]}\";\n"
    end
  end

  module LoadLocalizedData
    def self.load_data_from_local_xlsx
      workbook = Roo::Spreadsheet.open(XLSX_PATH)
      worksheet = workbook.sheet(0)
      localized_datas = []
      (2..worksheet.last_row).each do |row|
        row_data = worksheet.row(row)
        data = LocalizedData.new
        data.localized_key = row_data[0]
        (0..LANGUAGE.length-1).each do |i|
          data[LANGUAGE[i]] = row_data[i+1]
        end
        localized_datas.append(data)
      end
      localized_datas
    end

  end

  # path: 存放国际化的文件夹，其中存放.lproj
  # strings_name: .strings文件名
  # group_path: xcode中存放国际化的路径
  def self.update_localized(data, path, strings_name)

    project = Xcodeproj::Project.open(PROJECT_PROJ_PATH)
    varint_group = XcodeTool.get_variant_group(project, strings_name)
    if varint_group.nil?
      # 创建varint_group以及在resource build_phase中引用
      strings_relative_path = path.relative_path_from(Pathname(PROJECT_PATH)).to_s
      xcode_group = project.main_group.find_subpath(strings_relative_path)
      varint_group = xcode_group.new_variant_group(strings_name+".strings")
      project.targets.first.resources_build_phase.add_file_reference(varint_group)
      project.save
    else
      unless path == varint_group.real_path
        raise "其他路径 #{varint_group.real_path} 存在相同文件名的.strings文件"
      end
    end

    LANGUAGE.each do |language|
      # zh-Hans.lproj 下的 localized.strings
      language_dir_name = "#{language}.lproj"
      language_dir = path+language_dir_name
      strings_path = language_dir+"#{strings_name}.strings"
      FileTool.find_dir(path, language_dir_name, true)
      if FileTool.find_file(language_dir, "#{strings_name}.strings", true).empty?
        XcodeTool.add_file_reference(language, varint_group, strings_path.relative_path_from(path))
        project.save
        XcodeTool.add_localize_language(language, project)
        project.save
      end
      #修改.strings
      update_hash = Hash.new
      data.each do |item|
        update_hash[item.localized_key] = item[language]
      end
      update_strings(update_hash, strings_path)
    end
  end

  def self.update_strings(update_hash, strings_path)
    # 原来.string中的键值对
    line_hash = Hash.new
    repeat_hash = Hash.new
    file_data = File.open(strings_path).read
    clean_strings = FormatParsing.remove_comments_and_empty(file_data)

    clean_strings.each_line do |line|
      next if line.to_s.start_with?('//') || line.to_s.start_with?('/*')
      hash_key, hash_value = FormatParsing.parsing_localized_string(line, strings_path)
      # 查原来.string键值对的重
      analysis_repeat(line_hash, repeat_hash, hash_key, hash_value)
    end
    #直接merge
    line_hash = line_hash.merge(update_hash)
    #删除重复键值对
    line_hash.delete_if { |k, v| repeat_hash.has_key?(k) }
    sort_save(line_hash, repeat_hash, strings_path)
    plutil_check = `plutil #{strings_path}`
    puts plutil_check
  end

  def self.analysis_repeat(line_hash, repeat_hash, key, value)
    if line_hash.has_key?(key)
      old_hash_value = line_hash[key].strip
      # 旧值不为空且与新值不同，，提示
      if old_hash_value != value && !old_hash_value.to_s.empty? && !value.to_s.empty?
        values = repeat_hash[key] || []
        values << old_hash_value
        values << value
        repeat_hash[key] = values
        line_hash.delete(key)
        return
      end
    end
    line_hash[key] = value
  end

  def self.sort_save(line_hash, repeat_hash, strings_path)
    sort_file = "#{strings_path}.sorted"
    FileUtils.rm sort_file if File.exist? sort_file
    sort_keys = line_hash.keys.sort
    empty_hash_value = {}
    File.open(sort_file, 'w+') do |f|
      # 正常的国际化
      sort_keys.each do |key|
        value = line_hash[key]
        if value.to_s.empty?
          empty_hash_value[key] = value
          next
        end
        value = line_hash[key].to_s
        f << "\"#{key}\" = \"#{value}\";\n"
      end

      f << "/* MARK: ---- 以下key都是空的国际化 ---- 注意检查 */\n" if empty_hash_value.count > 0
      # 空的国际化
      empty_hash_value.each do |k, v|
        f << "\"#{k}\" = \"#{v}\";\n"
      end

      f << "/* MARK: ---- 以下key有重复---- 注意检查*/ \n" if repeat_hash.count > 0
      # 重复的国际化
      repeat_hash.each { |k, v|
        v.uniq.each do |value|
          next if value.nil? || value.to_s.empty?
          f << "\"#{k}\" = \"#{value}\";\n"
        end
      }
    end
    FileUtils.rm strings_path if File.exist?(strings_path)
    FileUtils.cp sort_file, strings_path
    FileUtils.rm sort_file
  end

end

datas = Localized::LoadLocalizedData.load_data_from_local_xlsx
Localized.update_localized(datas, Pathname(STRINGS_DIR), STRINGS_NAME)


# 1. 读取国际化文案(load data) -
# 2. 转成hash map(原有占位符需要进行替换，比如%s转成%@) -
# 3. 对比原有.strings进行新增和覆盖 -
# 4. 若不存在strings则新建strings并建立引用 -
# 5. 若存在任何一种语言的strings则不用建立引用 -
# 6. 寻找未使用过的国际化文案
# 7. 国际化文案校验 -
# 8. 国际化文案为空，重复提示 -
# 9. 便利方法
#
# 原有多个strings文件合并，整合成一个
# 整理代码