class FileHelper
  def self.parse_vhd_version(vhd_filename)
    md = vhd_filename.match(/.+\.patched-(\d+-\d+)$/)
    if md[1]
      return md[1]
    else
      raise "Could not parse version from vhd file: #{vhd_filename}"
    end
  end
end
