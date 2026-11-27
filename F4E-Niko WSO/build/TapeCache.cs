using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

internal static class TapeCache {
    private sealed class Member {
        public string Name;
        public int Offset, Size, End;
    }

    private static int Octal(byte[] data, int offset, int count) {
        string field = Encoding.ASCII.GetString(data, offset, count).Trim('\0', ' ');
        return field.Length == 0 ? 0 : Convert.ToInt32(field, 8);
    }

    private static string NameField(byte[] data, int offset, int size) {
        int end = Array.IndexOf(data, (byte)0, offset, size);
        return Encoding.ASCII.GetString(data, offset, end < 0 ? size : end - offset);
    }

    private static List<Member> ReadMembers(byte[] data, out int endOfMembers) {
        var entries = new List<Member>();
        int offset = 0;
        while (offset <= data.Length - 512 && data[offset] != 0) {
            int checksum = 0;
            for (int i = 0; i < 512; i++)
                checksum += i >= 148 && i < 156 ? 32 : data[offset + i];
            if (checksum != Octal(data, offset + 148, 8))
                throw new InvalidDataException("The Tape Player sound cache has an invalid header.");
            int size = Octal(data, offset + 124, 12);
            long end = offset + 512L + (size + 511L) / 512 * 512;
            if (end > data.Length) throw new InvalidDataException("Incomplete sound cache member.");
            string name = NameField(data, offset, 100);
            string prefix = NameField(data, offset + 345, 155);
            if (prefix.Length > 0) name = prefix + "/" + name;
            entries.Add(new Member { Name = name, Offset = offset, End = (int)end, Size = size });
            offset = (int)end;
        }
        if (data.Length - offset < 1024) throw new InvalidDataException("Incomplete sound cache terminator.");
        for (int i = offset; i < data.Length; i++)
            if (data[i] != 0) throw new InvalidDataException("Unexpected sound cache trailer.");
        endOfMembers = offset;
        return entries;
    }

    // Keep all unrelated member headers, padding and data intact. Only remove
    // definitions inserted by this installation, even if another mod edits the cache.
    public static byte[] Merge(byte[] cache, byte[] patch, bool install, string[] previous, out string[] owned) {
        int trailer, patchTrailer;
        var original = ReadMembers(cache, out trailer);
        var additions = ReadMembers(patch, out patchTrailer);
        var wanted = new Dictionary<string, Member>(StringComparer.OrdinalIgnoreCase);
        foreach (var entry in additions) wanted.Add(entry.Name, entry);
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var ours = new HashSet<string>(previous ?? new string[0], StringComparer.OrdinalIgnoreCase);
        ours.IntersectWith(wanted.Keys);
        using (var result = new MemoryStream()) {
            foreach (var entry in original) {
                Member supplied;
                if (wanted.TryGetValue(entry.Name, out supplied) && (install || ours.Contains(entry.Name))) {
                    if (!seen.Add(entry.Name) || entry.Size != supplied.Size)
                        throw new InvalidDataException("Conflicting Tape Player definition: " + entry.Name);
                    for (int i = 0; i < entry.Size; i++)
                        if (cache[entry.Offset + 512 + i] != patch[supplied.Offset + 512 + i])
                            throw new InvalidDataException("Modified Tape Player definition: " + entry.Name);
                    if (!install) continue;
                }
                result.Write(cache, entry.Offset, entry.End - entry.Offset);
            }
            if (install) {
                foreach (var entry in additions) {
                    if (seen.Contains(entry.Name)) continue;
                    result.Write(patch, entry.Offset, entry.End - entry.Offset);
                    ours.Add(entry.Name);
                }
            }
            result.Write(cache, trailer, cache.Length - trailer);
            owned = new string[ours.Count];
            ours.CopyTo(owned);
            Array.Sort(owned, StringComparer.Ordinal);
            return result.ToArray();
        }
    }
}
