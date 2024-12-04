%DUMPMSGPACK dumps Matlab data structures as a msgpack data
% DUMPMSGPACK(DATA)
%    recursively walks through DATA and creates a msgpack byte buffer from it.
%    - strings are converted to strings
%    - scalars are converted to numbers
%    - logicals are converted to `true` and `false`
%    - arrays are converted to arrays of numbers
%    - matrices are converted to arrays of arrays of numbers
%    - empty matrices are converted to nil
%    - cell arrays are converted to arrays
%    - cell matrices are converted to arrays of arrays
%    - struct arrays are converted to arrays of maps
%    - structs and container.Maps are converted to maps
%    - function handles and matlab objects will raise an error.
%
%    There is no way of encoding bins or exts

% (c) 2016 Bastian Bechtold
% This code is licensed under the BSD 3-clause license

function msgpack = dumpmsgpack(data)
    if isnumeric(data) && isscalar(data)
        if data >= 0 && data <= 127
            msgpack = uint8(data); % positive fixint
        elseif data >= -32 && data < 0
            msgpack = typecast(int8(data), 'uint8'); % negative fixint
        else
            error('Number out of range for fixint encoding.');
        end
    elseif ischar(data) || isstring(data)
        str = char(data); % 转换为字符数组
        len = length(str);
        if len <= 31
            msgpack = [uint8(160 + len), uint8(str)]; % fixstr
        elseif len <= 255
            msgpack = [uint8(217), uint8(len), uint8(str)]; % str8
        else
            error('String length too large for encoding.');
        end
    elseif islogical(data)
        msgpack = uint8(195 * data + 194 * ~data); % true or false
    elseif isempty(data)
        msgpack = uint8(192); % nil
    elseif iscell(data)
        len = numel(data);
        if len <= 15
            header = uint8(144 + len); % fixarray
        else
            header = [uint8(220), typecast(uint16(len), 'uint8')]; % array16
        end
        msgpack = header;
        for n = 1:len
            msgpack = [msgpack, dumpmsgpack(data{n})]; %#ok<AGROW>
        end
    elseif isstruct(data)
        fields = fieldnames(data);
        len = numel(fields);
        if len <= 15
            header = uint8(128 + len); % fixmap
        else
            header = [uint8(222), typecast(uint16(len), 'uint8')]; % map16
        end
        msgpack = header;
        for n = 1:len
            key = dumpmsgpack(fields{n});
            value = dumpmsgpack(data.(fields{n}));
            msgpack = [msgpack, key, value]; %#ok<AGROW>
        end
    elseif isa(data, 'containers.Map')
        keys = data.keys;
        len = numel(keys);
        if len <= 15
            header = uint8(128 + len); % fixmap
        else
            header = [uint8(222), typecast(uint16(len), 'uint8')]; % map16
        end
        msgpack = header;
        for n = 1:len
            key = dumpmsgpack(keys{n});
            value = dumpmsgpack(data(keys{n}));
            msgpack = [msgpack, key, value]; %#ok<AGROW>
        end
    else
        error('Unsupported data type for MsgPack serialization.');
    end
end
