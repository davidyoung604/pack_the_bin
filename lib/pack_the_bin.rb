# Methods for reading and unpacking binary data stored in a file.
# All methods expect "fields" param to be an array of hashes, each with
# mandatory keys :name, :offset, :length, :type. All other keys are ignored.
# e.g.
# fields = [
#   { name: :endian, offset: 0, length: 2, type: :str },
#   { name: :version, offset: 2, length: 2, type: :uint },
#   { name: :img_dir_offset, offset: 4, length: 4, type: :uint }
# ]
class PackTheBin
  # minimize total file reads with this:
  # IO.read(file, 8, 0).unpack('a2a2a4')
  # => ["II", "*\x00", "\x10\x00\x00\x00"]

  def initialize(filename)
    @file = filename
  end

  def read_fields(fields, offset = 0)
    self.class.load_from_file(@file, fields, offset)
  end

  def self.load_from_file(filename, fields, offset = 0)
    total_len = size(fields)
    bytes = IO.read(filename, total_len, offset)
    bytes_to_fields(bytes, fields)
  end

  def self.size(fields)
    fields.reduce(0) { |a, e| a + e[:length] }
  end

  def self.convert(data, from_type, from_len, to_type, to_len)
    from = type_to_str(from_type, from_len)
    to = type_to_str(to_type, to_len)
    [data].pack(from).unpack(to)[0]
  end

  private_class_method

  def self.build_unpack_str(fields)
    fields.map do |f|
      type_to_str(f[:type], f[:length])
    end.join
  end

  def self.type_to_str(type, length)
    case type
    when :byte
      "H#{length * 2}" # requires additional processing if raw bytes are wanted
    when :double
      'd'
    when :float
      'f'
    when :int, :uint
      int_unpack_str(type, length)
    when :str
      "A#{length}"
    end
  end

  def self.int_unpack_str(type, len)
    str = case len
          when 1
            'c'
          when 2
            's'
          when 4
            'l'
          else
            'q'
          end

    type == :uint ? str.upcase : str
  end

  def self.bytes_to_fields(bytes, fields)
    unpacked = {}
    unpack_str = build_unpack_str(fields)
    bytes.unpack(unpack_str).each_with_index do |val, i|
      field_name = fields[i][:name]
      unpacked[field_name] = val
    end
    unpacked
  end
end
