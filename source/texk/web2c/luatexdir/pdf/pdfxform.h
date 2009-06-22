/* pdfxform.h

   Copyright 2009 Taco Hoekwater <taco@luatex.org>

   This file is part of LuaTeX.

   LuaTeX is free software; you can redistribute it and/or modify it under
   the terms of the GNU General Public License as published by the Free
   Software Foundation; either version 2 of the License, or (at your
   option) any later version.

   LuaTeX is distributed in the hope that it will be useful, but WITHOUT
   ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
   FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
   License for more details.

   You should have received a copy of the GNU General Public License along
   with LuaTeX; if not, see <http://www.gnu.org/licenses/>. */

/* $Id$ */

#ifndef PDFXFORM_H
#  define PDFXFORM_H

/* data structure for \.{\\pdfxform} and \.{\\pdfrefxform} */

#  define pdfmem_xform_size        6    /* size of memory in |pdf_mem| which |obj_data_ptr| holds */

#  define obj_xform_width(A)       pdf_mem[obj_data_ptr(A) + 0]
#  define obj_xform_height(A)      pdf_mem[obj_data_ptr(A) + 1]
#  define obj_xform_depth(A)       pdf_mem[obj_data_ptr(A) + 2]
#  define obj_xform_box(A)         pdf_mem[obj_data_ptr(A) + 3] /* this field holds
                                                                   pointer to the corresponding box */
#  define obj_xform_attr(A)        pdf_mem[obj_data_ptr(A) + 4] /* additional xform
                                                                   attributes */
#  define obj_xform_resources(A)   pdf_mem[obj_data_ptr(A) + 5] /* additional xform
                                                                   Resources */


#  define set_pdf_xform_objnum(A,B) pdf_xform_objnum(A)=B
#  define set_obj_xform_width(A,B) obj_xform_width(A)=B
#  define set_obj_xform_height(A,B) obj_xform_height(A)=B
#  define set_obj_xform_depth(A,B) obj_xform_depth(A)=B
#  define set_obj_xform_box(A,B) obj_xform_box(A)=B
#  define set_obj_xform_attr(A,B) obj_xform_attr(A)=B
#  define set_obj_xform_resources(A,B) obj_xform_resources(A)=B

extern void output_form(halfword p);

#endif