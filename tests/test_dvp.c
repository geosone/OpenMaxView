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
    data[0x16f] = 0x12;
    data[0x170] = 0x34;
    data[0x171] = 'E';
    data[0x172] = 'D';
    put_word(data, 0x173, 1000);
    put_word(data, 0x175, 7);
    data[0x17e] = 2;
    put_word(data, 0x182, 2048);
    data[0x184] = 0x56;
    data[0x186] = 1;
    put_word(data, 0x187, 8);
    data[0x18a] = 3;
    data[0x18b] = 0x78;
    data[0x18c] = 0x9a;
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
    assert(program.profile.version == ODQ_PROFILE_VERSION);
    assert(program.profile.source_version == 2);
    assert(program.profile.system_kb == 4);
    assert(program.profile.script_bytes == 1000);
    assert(program.profile.idle_polls == 7);
    assert(program.profile.max_ems_kb == 2048);
    assert(program.profile.extra_system == 8);
    assert(program.profile.rows == 25 && program.profile.columns == 80);
    assert(program.profile.text_pages == 2 &&
           program.profile.graphics_pages == 1);
    assert(program.profile.serial_ports == 3);
    assert(program.profile.protection == 0x9a);
    assert(program.profile.flags1 == 0x12 &&
           program.profile.flags2 == 0x34 &&
           program.profile.flags3 == 0x56 &&
           program.profile.flags4 == 0x78);

    make_sample(path, 0);
    assert(dvp_load(path, &info) == DVP_CHECKSUM);
    if (argc >= 2 && strcmp(argv[1], "--keep") == 0)
        make_sample(path, 1);
    else
        remove(path);
    puts("DVP parser tests passed");
    return 0;
}
