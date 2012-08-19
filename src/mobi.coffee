fs = require 'fs'
Packer = require 'pypacker'

class Mobi
  constructor: (filename) ->
    @filename = filename
    @info = {'content': '', 'pdbHeader': {'records': []}, 'mobiHeader': {}}
    @parse()
    return @info

  parse: ->
    filename = @filename
    file_info = fs.statSync(filename)
    buffer = new Buffer(file_info.size)

    fd = fs.openSync(filename, 'r')
    fs.readSync(fd, buffer, 0, file_info.size, 0)

    ##
    # Parse the PDB header!
    ##
    pdbHeader = @info.pdbHeader

    # Fill in some basic fields.
    [
      @info.name, pdbHeader.attributes, pdbHeader.version, pdbHeader.created,
      pdbHeader.modified, pdbHeader.backedUp, pdbHeader.modificationNumber,
      pdbHeader.appInfoId, pdbHeader.sortInfoID, pdbHeader.type,
      pdbHeader.creator, pdbHeader.uniqueIDseed, pdbHeader.nextRecordListID,
      pdbHeader.recordCount
    ] = new Packer('31sxHH6I4s4s2IH').unpack_from(buffer)

    # Trim the name
    @info.name = @info.name.replace(/\u0000/g, "")

    # Fix the dates
    pdbHeader.created = new Date(pdbHeader.created * 1000)
    pdbHeader.modified = new Date(pdbHeader.modified * 1000)
    pdbHeader.backedUp = new Date(pdbHeader.backedUp * 100)

    # Push the memory positions of the records.
    bufIndex = 0x4E
    for index in [0...pdbHeader.recordCount]
      startPosition = bufIndex + (index*8)
      [position, id] = new Packer('II').unpack_from(buffer, startPosition)
      id = id & 0x00FFFFFF
      pdbHeader.records.push({"position": position, "id": id})

    ##
    # Parse the mobi header
    ##
    header = buffer.slice(pdbHeader.records[0].position, pdbHeader.records[1].position)
    mobiHeader = @info.mobiHeader

    [
      mobiHeader.compression, mobiHeader.text_length,
      mobiHeader.textRecordCount, mobiHeader.recordSize, mobiHeader.encryption,
      mobiHeader.headerLength, mobiHeader.mobiType, mobiHeader.encoding
    ] = new Packer('H2xI3H6x3I').unpack_from(header)

    [
      mobiHeader.firstNonBookIndex, mobiHeader.fullNameOffset,
      mobiHeader.fullNameLength
    ] = new Packer('3I').unpack_from(header, 0x50)

    [mobiHeader.firstImageIndex] = new Packer('I').unpack_from(header, 0x6C)

    # Are there EXTH tags?
    [mobiHeader.exthFlags] = new Packer('I').unpack_from(header, 0x80)
    mobiHeader.exthFlags = if ((mobiHeader.exthFlags & 0x40) is 0x40) then true else false

    [
      mobiHeader.firstContentRecord, mobiHeader.lastContentRecord
    ] = new Packer('2H').unpack_from(header, 0xC2)

    # Set the title
    [@info.title] = new Packer("#{ mobiHeader.fullNameLength }s")
      .unpack_from(header, mobiHeader.fullNameOffset)

    # Records can have trailing data.
    multibyte = 0
    trailers = 0

    if mobiHeader.headerLength >= 0xE4
      flags = [mobiHeader.flags] = new Packer('H').unpack_from(header, 0xF2)
      multibyte = flags & 1
      while flags > 1
        trailers += 1
        flags = flags & (flags - 2)

    ##
    # Iterate over all the records.
    ##
    for position in [1..mobiHeader.textRecordCount]
      data = buffer.slice(pdbHeader.records[position].position,
        pdbHeader.records[position+1].position)

      # Trim the data
      data = @trim(data, trailers, multibyte)

      # Append to the content string!
      if mobiHeader.compression is 1
        @info.content += data
      else if mobiHeader.compression is 2
        @info.content += @palmdocReader(data)
      else
        throw new Error("LZ77 compression isn't supported... yet.")

    @info.content = @info.content.replace(/<(head|HEAD)>/g,
      '<head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>')

  trim: (data, trailers, multibyte) ->
    for z in [0...trailers]
        num = 0
        end_bytes = data.slice(data.length-4)
        for v in [0...4]
          if end_bytes[v] & 0x80
            num = 0
          num = (num << 7) | (end_bytes[v] & 0x7F)
        data = data.slice(0, data.length-num)
      if multibyte
        num = (data[data.length-1] & 3) + 1
        data = data.slice(0, data.length-num)

    data



  palmdocReader: (data) ->
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

exports = module.exports = Mobi
