"""Write fixture.tar, the smoke test's input, byte for byte the same on every run.

  python3 -I fixture.py fixture.tar

Every header field is fixed (names, modes, owners, times, a PAX xattr), and the
data is a fixed text and a fixed-seed byte stream, so the tar, and the images
mkfs.erofs makes from it, depend on nothing but this file. The CI never runs
it: fixture.tar is committed; this records how it was made.
"""

import io
import random
import sys
import tarfile

MTIME = 1700000000
TEXT = b"".join(b"line %05d: the quick brown fox jumps over the lazy dog\n" % i for i in range(600))
NOISE = random.Random(20261030).randbytes(12288)


def member(name, kind=tarfile.REGTYPE, mode=0o644, uid=0, gid=0, **extra):
    info = tarfile.TarInfo(name)
    info.type = kind
    info.mode = mode
    info.uid, info.gid = uid, gid
    info.uname = info.gname = ""
    info.mtime = MTIME
    for key, value in extra.items():
        setattr(info, key, value)
    return info


def main(path):
    with open(path, "wb") as raw, tarfile.open(fileobj=raw, mode="w", format=tarfile.PAX_FORMAT) as tar:
        def add(info, data=b""):
            info.size = len(data)
            tar.addfile(info, io.BytesIO(data) if data else None)

        add(member("dir", tarfile.DIRTYPE, 0o755))
        add(member("dir/sub", tarfile.DIRTYPE, 0o750, uid=1000, gid=1000))
        add(member("dir/small.txt"), b"a file small enough to inline\n")
        add(member("dir/empty"))
        add(member("dir/text.txt"), TEXT)
        add(member("dir/sub/noise.bin", mode=0o600, uid=1000, gid=1000), NOISE)
        add(member("dir/sub/run.sh", mode=0o755), b"#!/bin/sh\necho erofs\n")
        add(member("dir/high-ids", uid=70000, gid=65534), b"owner and group above 16 bits\n")
        add(member("dir/" + "long-name-" * 12 + "end"), b"a name past the ustar limit\n")
        add(member("dir/xattr", pax_headers={"SCHILY.xattr.user.testbin": "erofs"}), b"with a user xattr\n")
        add(member("dir/link", tarfile.SYMTYPE, 0o777, linkname="small.txt"))
        add(member("dir/hard", tarfile.LNKTYPE, linkname="dir/small.txt"))


if __name__ == "__main__":
    main(sys.argv[1])
