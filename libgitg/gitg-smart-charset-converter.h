/*
 * gedit-smart-charset-converter.h
 * This file is part of gedit
 *
 * Copyright (C) 2009 - Ignacio Casal Quinteiro
 *
 * gedit is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * gedit is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with gedit; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, 
 * Boston, MA  02110-1301  USA
 */

#ifndef __GITG_SMART_CHARSET_CONVERTER_H__
#define __GITG_SMART_CHARSET_CONVERTER_H__

#include <glib-object.h>

#include "gitg-encodings.h"

G_BEGIN_DECLS

#define GITG_TYPE_SMART_CHARSET_CONVERTER		(gitg_smart_charset_converter_get_type ())
#define GITG_SMART_CHARSET_CONVERTER(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_SMART_CHARSET_CONVERTER, GitgSmartCharsetConverter))
#define GITG_SMART_CHARSET_CONVERTER_CONST(obj)	(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_SMART_CHARSET_CONVERTER, GitgSmartCharsetConverter const))
#define GITG_SMART_CHARSET_CONVERTER_CLASS(klass)	(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_SMART_CHARSET_CONVERTER, GitgSmartCharsetConverterClass))
#define GITG_IS_SMART_CHARSET_CONVERTER(obj)		(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_SMART_CHARSET_CONVERTER))
#define GITG_IS_SMART_CHARSET_CONVERTER_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_SMART_CHARSET_CONVERTER))
#define GITG_SMART_CHARSET_CONVERTER_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_SMART_CHARSET_CONVERTER, GitgSmartCharsetConverterClass))

typedef struct _GitgSmartCharsetConverter		GitgSmartCharsetConverter;
typedef struct _GitgSmartCharsetConverterClass		GitgSmartCharsetConverterClass;
typedef struct _GitgSmartCharsetConverterPrivate	GitgSmartCharsetConverterPrivate;

#define GITG_CHARSET_CONVERSION_ERROR (gitg_charset_conversion_error_quark ())

typedef enum
{
	GITG_CHARSET_CONVERSION_ERROR_ENCODING_AUTO_DETECTION_FAILED
} GitgCharserConversionError;

struct _GitgSmartCharsetConverter
{
	GObject parent;
	
	GitgSmartCharsetConverterPrivate *priv;
};

struct _GitgSmartCharsetConverterClass
{
	GObjectClass parent_class;
};

GType gitg_smart_charset_converter_get_type (void) G_GNUC_CONST;
GQuark gitg_charset_conversion_error_quark (void);

GitgSmartCharsetConverter	*gitg_smart_charset_converter_new		(GSList *candidate_encodings);

const GitgEncoding		*gitg_smart_charset_converter_get_guessed	(GitgSmartCharsetConverter *smart);

guint				 gitg_smart_charset_converter_get_num_fallbacks(GitgSmartCharsetConverter *smart);

G_END_DECLS

#endif /* __GITG_SMART_CHARSET_CONVERTER_H__ */

/* ex:ts=8:noet: */
