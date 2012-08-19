decompress = (data) ->
  string = ''
  index = 0
  while index < data.length
    frame = data[index]
    index += 1
    if frame >= 1 and frame <= 8
      string += data.toString('utf8', index, index+frame)

      # Javascript doesn't count then number of bytes in a string so we have
      # to put in a filler character that will be replaced later.
      for x in [0...frame-1]
        string += String.fromCharCode(0xE0E0)
      index += frame
    else if frame < 128
      string += String.fromCharCode(frame)
    else if frame >= 192
      string += ' ' + String.fromCharCode(frame ^ 128)
    else
      concat = (frame << 8) | data[index]
      distance = ((concat >> 3) & 0x07FF)
      length = (concat & 7) + 3
      if length < distance
        string += string.slice(-distance, length-distance)
      else
        for x in [0...length]
          string += string[string.length-distance]
      index += 1

  # Trim the string down to size and replace our character.
  string = string.replace(/\uE0E0/g,'')
  string

compress = (data) ->
  throw new Error("Palmdoc Compression not supported yet.")

exports.compress = module.exports.compress = compress
exports.decompress = module.exports.decompress = decompress
