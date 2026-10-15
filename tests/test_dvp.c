/* SPDX-License-Identifier: GPL-3.0-or-later */
#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "dvp.h"

static void put_word(unsigned char *data, unsigned offset, unsigned value)
{
    data[offset] = (unsigned char)value;
    data[offset + 1] = (unsigned char)(value >> 8);
}

static void make_sample(const char *path, int valid_checksum)
{
    unsigned char data[DVP_20_SIZE];
    FILE *stream;
    unsigned index, checksum = 0;

    memset(data, 0, sizeof(data));
    memset(data + 2, ' ', 30);
    memcpy(data + 2, "Sample editor", 13);
    put_word(data, 0x20, 640);
    put_word(data, 0x22, 192);
    strcpy((char *)data + 0x24, "C:\\DOS\\EDIT.COM");
    data[0x64] = 'C';
    strcpy((char *)data + 0x65, "\\WORK");
    strcpy((char *)data + 0xa5, "NOTES.TXT");
    data[0xe6] = 2;
    data[0xe9] = 25;
    data[0xea] = 80;
    put_word(data, 0xed, 4);
    data[0x171] = 'E';
    data[0x172] = 'D';
    put_word(data, 0x173, 1000);
    data[0x17e] = 2;
    put_word(data, 0x182, 2048);
    data[0x186] = 1;
    for (index = 2; index <= 0x170; ++index)
        checksum = (checksum + data[index]) & 0xff;
    data[1] = (unsigned char)(valid_checksum ? checksum : checksum + 1);
    stream = fopen(path, "wb");
    assert(stream != NULL);
    assert(fwrite(data, 1, sizeof(data), stream) == sizeof(data));
    assert(fclose(stream) == 0);
}

int main(int argc, char **argv)
{
    const char *path = "build/test.dvp";
    dvp_info info;
    odq_program program;

    make_sample(path, 1);
    assert(dvp_load(path, &info) == DVP_OK);
    assert(strcmp(info.title, "Sample editor") == 0);
    assert(strcmp(info.pathname, "C:\\DOS\\EDIT.COM") == 0);
    assert(strcmp(info.directory, "\\WORK") == 0);
    assert(strcmp(info.parameters, "NOTES.TXT") == 0);
    assert(strcmp(info.menu_keys, "ED") == 0);
    assert(info.min_kb == 192 && info.max_kb == 640);
    assert(info.has_v20 && info.version == 2);
    assert(info.script_bytes == 1000 && info.max_ems_kb == 2048);
    assert(dvp_make_program(&info, 'Q', &program) == DVP_OK);
    assert(program.hotkey == 'Q');
    assert(strcmp(program.directory, "C:\\WORK") == 0);
    assert(strcmp(program.command,
                  "C:\\DOS\\EDIT.COM NOTES.TXT") == 0);

    make_sample(path, 0);
    assert(dvp_load(path, &info) == DVP_CHECKSUM);
    if (argc >= 2 && strcmp(argv[1], "--keep") == 0)
        make_sample(path, 1);
    else
        remove(path);
    puts("DVP parser tests passed");
    return 0;
}
