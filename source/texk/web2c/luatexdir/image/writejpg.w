% writejpg.w
%
% Copyright 1996-2006 Han The Thanh <thanh@@pdftex.org>
% Copyright 2006-2011 Taco Hoekwater <taco@@luatex.org>
%
% This file is part of LuaTeX.
%
% LuaTeX is free software; you can redistribute it and/or modify it under
% the terms of the GNU General Public License as published by the Free
% Software Foundation; either version 2 of the License, or (at your
% option) any later version.
%
% LuaTeX is distributed in the hope that it will be useful, but WITHOUT
% ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
% FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
% License for more details.
%
% You should have received a copy of the GNU General Public License along
% with LuaTeX; if not, see <http://www.gnu.org/licenses/>.

@ @c


#include "ptexlib.h"
#include <assert.h>
#include "image/image.h"
#include "image/writejpg.h"

@ @c
#define JPG_GRAY  1             /* Gray color space, use /DeviceGray    */
#define JPG_RGB   3             /* RGB color space, use /DeviceRGB      */
#define JPG_CMYK  4             /* CMYK color space, use /DeviceCMYK    */

typedef enum {                  /* JPEG marker codes                    */
    M_SOF0 = 0xc0,              /* baseline DCT                         */
    M_SOF1 = 0xc1,              /* extended sequential DCT              */
    M_SOF2 = 0xc2,              /* progressive DCT                      */
    M_SOF3 = 0xc3,              /* lossless (sequential)                */

    M_SOF5 = 0xc5,              /* differential sequential DCT          */
    M_SOF6 = 0xc6,              /* differential progressive DCT         */
    M_SOF7 = 0xc7,              /* differential lossless (sequential)   */

    M_JPG = 0xc8,               /* reserved for JPEG extensions         */
    M_SOF9 = 0xc9,              /* extended sequential DCT              */
    M_SOF10 = 0xca,             /* progressive DCT                      */
    M_SOF11 = 0xcb,             /* lossless (sequential)                */

    M_SOF13 = 0xcd,             /* differential sequential DCT          */
    M_SOF14 = 0xce,             /* differential progressive DCT         */
    M_SOF15 = 0xcf,             /* differential lossless (sequential)   */

    M_DHT = 0xc4,               /* define Huffman table(s)              */

    M_DAC = 0xcc,               /* define arithmetic conditioning table */

    M_RST0 = 0xd0,              /* restart                              */
    M_RST1 = 0xd1,              /* restart                              */
    M_RST2 = 0xd2,              /* restart                              */
    M_RST3 = 0xd3,              /* restart                              */
    M_RST4 = 0xd4,              /* restart                              */
    M_RST5 = 0xd5,              /* restart                              */
    M_RST6 = 0xd6,              /* restart                              */
    M_RST7 = 0xd7,              /* restart                              */

    M_SOI = 0xd8,               /* start of image                       */
    M_EOI = 0xd9,               /* end of image                         */
    M_SOS = 0xda,               /* start of scan                        */
    M_DQT = 0xdb,               /* define quantization tables           */
    M_DNL = 0xdc,               /* define number of lines               */
    M_DRI = 0xdd,               /* define restart interval              */
    M_DHP = 0xde,               /* define hierarchical progression      */
    M_EXP = 0xdf,               /* expand reference image(s)            */

    M_APP0 = 0xe0,              /* application marker, used for JFIF    */
    M_APP1 = 0xe1,              /* application marker                   */
    M_APP2 = 0xe2,              /* application marker                   */
    M_APP3 = 0xe3,              /* application marker                   */
    M_APP4 = 0xe4,              /* application marker                   */
    M_APP5 = 0xe5,              /* application marker                   */
    M_APP6 = 0xe6,              /* application marker                   */
    M_APP7 = 0xe7,              /* application marker                   */
    M_APP8 = 0xe8,              /* application marker                   */
    M_APP9 = 0xe9,              /* application marker                   */
    M_APP10 = 0xea,             /* application marker                   */
    M_APP11 = 0xeb,             /* application marker                   */
    M_APP12 = 0xec,             /* application marker                   */
    M_APP13 = 0xed,             /* application marker                   */
    M_APP14 = 0xee,             /* application marker, used by Adobe    */
    M_APP15 = 0xef,             /* application marker                   */

    M_JPG0 = 0xf0,              /* reserved for JPEG extensions         */
    M_JPG13 = 0xfd,             /* reserved for JPEG extensions         */
    M_COM = 0xfe,               /* comment                              */

    M_TEM = 0x01,               /* temporary use                        */

    M_ERROR = 0x100             /* dummy marker, internal use only      */
} JPEG_MARKER;

@ @c
static unsigned char
myget_unsigned_byte (FILE *file)
{
    int ch;
    ch = fgetc (file);
    return (unsigned char) ch;
}

@ @c
static unsigned short
myget_unsigned_pair (FILE *file)
{
    unsigned short pair = myget_unsigned_byte(file);
    pair = (pair << 8) | myget_unsigned_byte(file);
    return pair;
}

@ @c
static unsigned int
read_exif_bytes(unsigned char **p, int n, int b)
{
    unsigned int rval = 0;
    unsigned char *pp = *p;
    if (b) {
        switch (n) {
        case 4:
            rval += *pp++; rval <<= 8;
            rval += *pp++; rval <<= 8;
        case 2:
            rval += *pp++; rval <<= 8;
            rval += *pp;
            break;
        }
    } else {
        pp += n;
        switch (n) {
        case 4:
            rval += *--pp; rval <<= 8;
            rval += *--pp; rval <<= 8;
        case 2:
            rval += *--pp; rval <<= 8;
            rval += *--pp;
            break;
        }
    }
    *p += n;
    return rval;
}

@ @c
static void
read_APP1_Exif (FILE *fp, unsigned short length, int *xx, int *yy)
{
    /* this doesn't save the data, just reads the tags we need */
    /* based on info from http://www.exif.org/Exif2-2.PDF */
    unsigned char *buffer = (unsigned char *)xmalloc(length);
    unsigned char *p, *rp;
    unsigned char *tiff_header;
    char bigendian;
    int i;
    int num_fields, tag, type;
    int value = 0, num = 0, den = 0;	/* silence uninitialized warnings */
    double xres = 72.0;
    double yres = 72.0;
    double res_unit = 1.0;
    fread(buffer, length, 1, fp);
    p = buffer;
    while ((p < buffer + length) && (*p == 0))
        ++p;
    tiff_header = p;
    if ((*p == 'M') && (*(p+1) == 'M'))
        bigendian = 1;
    else if ((*p == 'I') && (*(p+1) == 'I'))
        bigendian = 0;
    else
        goto err;
    p += 2;
    i = read_exif_bytes(&p, 2, bigendian);
    if (i != 42)
        goto err;
    i = read_exif_bytes(&p, 4, bigendian);
    p = tiff_header + i;
    num_fields = read_exif_bytes(&p, 2, bigendian);
    while (num_fields-- > 0) {
        tag = read_exif_bytes(&p, 2, bigendian);
        type = read_exif_bytes(&p, 2, bigendian);
        read_exif_bytes(&p, 4, bigendian);
        switch (type) {
        case 1: /* byte */
            value = *p++;
            p += 3;
            break;
        case 3: /* short */
            value = read_exif_bytes(&p, 2, bigendian);
            p += 2;
            break;
        case 4: /* long */
        case 9: /* slong */
            value = read_exif_bytes(&p, 4, bigendian);
            break;
        case 5: /* rational */
        case 10: /* srational */
            value = read_exif_bytes(&p, 4, bigendian);
            rp = tiff_header + value;
            num = read_exif_bytes(&rp, 4, bigendian);
            den = read_exif_bytes(&rp, 4, bigendian);
            break;
        case 7: /* undefined */
            value = *p++;
            p += 3;
            break;
        case 2: /* ascii */
        default:
            p += 4;
            break;
	}
        switch (tag) {
        case 282: /* x res */
            if (den != 0)
                xres = num / den;
            break;
        case 283: /* y res */
            if (den != 0)
                yres = num / den;
            break;
        case 296: /* res unit */
            switch (value) {
            case 2:
                res_unit = 1.0;
                break;
            case 3:
                res_unit = 2.54;
                break;
            }
        }
    }

    *xx = (int)(xres * res_unit);
    *yy = (int)(yres * res_unit);

err:
    free(buffer);
    return;
}

@ @c
static void close_and_cleanup_jpg(image_dict * idict)
{
    assert(idict != NULL);
    assert(img_file(idict) != NULL);
    assert(img_filepath(idict) != NULL);
    xfclose(img_file(idict), img_filepath(idict));
    img_file(idict) = NULL;
    assert(img_jpg_ptr(idict) != NULL);
    xfree(img_jpg_ptr(idict));
}

@ @c
void read_jpg_info(PDF pdf, image_dict * idict, img_readtype_e readtype)
{
    int i, units = 0;
    unsigned short appmk, length;
    unsigned char jpg_id[] = "JFIF";
    assert(idict != NULL);
    assert(img_type(idict) == IMG_TYPE_JPG);
    img_totalpages(idict) = 1;
    img_pagenum(idict) = 1;
    img_xres(idict) = img_yres(idict) = 0;
    assert(img_file(idict) == NULL);
    img_file(idict) = xfopen(img_filepath(idict), FOPEN_RBIN_MODE);
    assert(img_jpg_ptr(idict) == NULL);
    img_jpg_ptr(idict) = xtalloc(1, jpg_img_struct);
    xfseek(img_file(idict), 0, SEEK_END, img_filepath(idict));
    img_jpg_ptr(idict)->length = xftell(img_file(idict), img_filepath(idict));
    xfseek(img_file(idict), 0, SEEK_SET, img_filepath(idict));
    if ((unsigned int) read2bytes(img_file(idict)) != 0xFFD8)
        luatex_fail("reading JPEG image failed (no JPEG header found)");
    /* currently JFIF and Exif files allow extracting |img_xres| and |img_yres| */
    appmk = read2bytes(img_file(idict));
    if (appmk == 0xFFE0) {     /* check for JFIF */
        (void) read2bytes(img_file(idict));
        for (i = 0; i < 5; i++) {
            if (xgetc(img_file(idict)) != jpg_id[i])
                break;
        }
        if (i == 5) {           /* it's JFIF */
            (void) read2bytes(img_file(idict));
            units = xgetc(img_file(idict));
            img_xres(idict) = (int) read2bytes(img_file(idict));
            img_yres(idict) = (int) read2bytes(img_file(idict));
            switch (units) {
            case 1:
                if ((img_xres(idict) == 1) || (img_yres(idict) == 1)) {
                    luatex_warn("The image specifies an unusual resolution of %ddpi by %ddpi. ",
                        img_xres(idict), img_yres(idict));
                }
                break;          /* pixels per inch */
            case 2:
                img_xres(idict) = (int) ((double) img_xres(idict) * 2.54);
                img_yres(idict) = (int) ((double) img_yres(idict) * 2.54);
                break;          /* pixels per cm */
            default:
                img_xres(idict) = img_yres(idict) = 0;
                break;
            }
        }
        /* if either xres or yres is 0 but the other isn't,
           set it to the value of the other */
        if ((img_xres(idict) == 0) && (img_yres(idict) != 0)) {
            img_xres(idict) = img_yres(idict);
        }
        if ((img_yres(idict) == 0) && (img_xres(idict) != 0)) {
            img_yres(idict) = img_xres(idict);
        }
    } else if (appmk == 0xFFE1) {  /* check for Exif */
        FILE *fp = img_file(idict);
        int xxres = 0;
        int yyres = 0;
        char app_sig[32];
        length = myget_unsigned_pair(fp) - 2;
        if (length > 5) {
            if (fread(app_sig, sizeof(char), 5, fp) != 5)
                return;
            length -= 5;
            if (!memcmp(app_sig, "Exif\000", 5)) {
                read_APP1_Exif(fp, length, &xxres, &yyres);
            }
        }
        img_xres(idict) = xxres;
        img_yres(idict) = yyres;
    }
    xfseek(img_file(idict), 0, SEEK_SET, img_filepath(idict));
    while (1) {
        if (feof(img_file(idict)))
            luatex_fail("reading JPEG image failed (premature file end)");
        if (fgetc(img_file(idict)) != 0xFF)
            luatex_fail("reading JPEG image failed (no marker found)");
        i = xgetc(img_file(idict));
        switch (i) {
        case M_SOF3:           /* lossless */
        case M_SOF5:
        case M_SOF6:
        case M_SOF7:           /* lossless */
        case M_SOF9:
        case M_SOF10:
        case M_SOF11:          /* lossless */
        case M_SOF13:
        case M_SOF14:
        case M_SOF15:          /* lossless */
            luatex_fail("unsupported type of compression (SOF_%d)", i - M_SOF0);
            break;
        case M_SOF2:
            if (pdf->minor_version <= 2)
                luatex_fail("cannot use progressive DCT with PDF-1.2");
        case M_SOF0:
        case M_SOF1:
            (void) read2bytes(img_file(idict)); /* read segment length  */
            img_colordepth(idict) = xgetc(img_file(idict));
            img_ysize(idict) = (int) read2bytes(img_file(idict));
            img_xsize(idict) = (int) read2bytes(img_file(idict));
            img_jpg_color(idict) = xgetc(img_file(idict));
            xfseek(img_file(idict), 0, SEEK_SET, img_filepath(idict));
            switch (img_jpg_color(idict)) {
            case JPG_GRAY:
                img_procset(idict) |= PROCSET_IMAGE_B;
                break;
            case JPG_RGB:
                img_procset(idict) |= PROCSET_IMAGE_C;
                break;
            case JPG_CMYK:
                img_procset(idict) |= PROCSET_IMAGE_C;
                break;
            default:
                luatex_fail("Unsupported color space %i",
                            (int) img_jpg_color(idict));
            }
            if (readtype == IMG_CLOSEINBETWEEN)
                close_and_cleanup_jpg(idict);
            return;
        case M_SOI:            /* ignore markers without parameters */
        case M_EOI:
        case M_TEM:
        case M_RST0:
        case M_RST1:
        case M_RST2:
        case M_RST3:
        case M_RST4:
        case M_RST5:
        case M_RST6:
        case M_RST7:
            break;
        default:               /* skip variable length markers */
            xfseek(img_file(idict), (int) read2bytes(img_file(idict)) - 2,
                   SEEK_CUR, img_filepath(idict));
            break;
        }
    }
    assert(0);
}

@ @c
static void reopen_jpg(PDF pdf, image_dict * idict)
{
    int width, height, xres, yres;
    width = img_xsize(idict);
    height = img_ysize(idict);
    xres = img_xres(idict);
    yres = img_yres(idict);
    read_jpg_info(pdf, idict, IMG_KEEPOPEN);
    if (width != img_xsize(idict) || height != img_ysize(idict)
        || xres != img_xres(idict) || yres != img_yres(idict))
        luatex_fail("writejpg: image dimensions have changed");
}

@ @c
void write_jpg(PDF pdf, image_dict * idict)
{
    size_t l;
    assert(idict != NULL);
    if (img_file(idict) == NULL)
        reopen_jpg(pdf, idict);
    assert(img_jpg_ptr(idict) != NULL);
    pdf_begin_obj(pdf, img_objnum(idict), OBJSTM_NEVER);
    pdf_begin_dict(pdf);
    pdf_dict_add_name(pdf, "Type", "XObject");
    pdf_dict_add_name(pdf, "Subtype", "Image");
    pdf_dict_add_img_filename(pdf, idict);
    if (img_attr(idict) != NULL && strlen(img_attr(idict)) > 0)
        pdf_printf(pdf, "\n%s\n", img_attr(idict));
    pdf_dict_add_int(pdf, "Width", (int) img_xsize(idict));
    pdf_dict_add_int(pdf, "Height", (int) img_ysize(idict));
    pdf_dict_add_int(pdf, "BitsPerComponent", (int) img_colordepth(idict));
    pdf_dict_add_int(pdf, "Length", (int) img_jpg_ptr(idict)->length);
    if (img_colorspace(idict) != 0) {
        pdf_dict_add_ref(pdf, "ColorSpace", (int) img_colorspace(idict));
    } else {
        switch (img_jpg_color(idict)) {
        case JPG_GRAY:
            pdf_dict_add_name(pdf, "ColorSpace", "DeviceGray");
            break;
        case JPG_RGB:
            pdf_dict_add_name(pdf, "ColorSpace", "DeviceRGB");
            break;
        case JPG_CMYK:
            pdf_dict_add_name(pdf, "ColorSpace", "DeviceCMYK");
            pdf_add_name(pdf, "Decode");
            pdf_begin_array(pdf);
            pdf_add_int(pdf, 1);
            pdf_add_int(pdf, 0);
            pdf_add_int(pdf, 1);
            pdf_add_int(pdf, 0);
            pdf_add_int(pdf, 1);
            pdf_add_int(pdf, 0);
            pdf_add_int(pdf, 1);
            pdf_add_int(pdf, 0);
            pdf_end_array(pdf);
            break;
        default:
            luatex_fail("Unsupported color space %i",
                        (int) img_jpg_color(idict));
        }
    }
    pdf_dict_add_name(pdf, "Filter", "DCTDecode");
    pdf_end_dict(pdf);
    pdf_begin_stream(pdf);
    assert(pdf->zip_write_state == NO_ZIP);
    l = (size_t) img_jpg_ptr(idict)->length;
    xfseek(img_file(idict), 0, SEEK_SET, img_filepath(idict));
    if (read_file_to_buf(pdf, img_file(idict), l) != l)
        luatex_fail("writejpg: fread failed");
    pdf_end_stream(pdf);
    pdf_end_obj(pdf);
    close_and_cleanup_jpg(idict);
}
