/*
 * This file was copied from gedit-encodings.c
 *
 * gedit-encodings.c
 * This file is part of gedit
 *
 * Copyright (C) 2002-2005 Paolo Maggi 
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, 
 * Boston, MA 02111-1307, USA.
 */
 
/*
 * Modified by the gedit Team, 2002-2005. See the AUTHORS file for a 
 * list of people on the gedit Team.  
 * See the ChangeLog files for a list of changes. 
 *
 * $Id$
 */

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <string.h>

#include <glib/gi18n.h>

#include "gitg-encodings.h"


struct _GitgEncoding
{
	gint   index;
	const gchar *charset;
	const gchar *name;
};

G_DEFINE_BOXED_TYPE (GitgEncoding, gitg_encoding,
                     gitg_encoding_copy,
                     gitg_encoding_free)

/* 
 * The original versions of the following tables are taken from profterm 
 *
 * Copyright (C) 2002 Red Hat, Inc.
 */

typedef enum
{

  GITG_ENCODING_ISO_8859_1,
  GITG_ENCODING_ISO_8859_2,
  GITG_ENCODING_ISO_8859_3,
  GITG_ENCODING_ISO_8859_4,
  GITG_ENCODING_ISO_8859_5,
  GITG_ENCODING_ISO_8859_6,
  GITG_ENCODING_ISO_8859_7,
  GITG_ENCODING_ISO_8859_8,
  GITG_ENCODING_ISO_8859_9,
  GITG_ENCODING_ISO_8859_10,
  GITG_ENCODING_ISO_8859_13,
  GITG_ENCODING_ISO_8859_14,
  GITG_ENCODING_ISO_8859_15,
  GITG_ENCODING_ISO_8859_16,

  GITG_ENCODING_UTF_7,
  GITG_ENCODING_UTF_16,
  GITG_ENCODING_UTF_16_BE,
  GITG_ENCODING_UTF_16_LE,
  GITG_ENCODING_UTF_32,
  GITG_ENCODING_UCS_2,
  GITG_ENCODING_UCS_4,

  GITG_ENCODING_ARMSCII_8,
  GITG_ENCODING_BIG5,
  GITG_ENCODING_BIG5_HKSCS,
  GITG_ENCODING_CP_866,

  GITG_ENCODING_EUC_JP,
  GITG_ENCODING_EUC_JP_MS,
  GITG_ENCODING_CP932,
  GITG_ENCODING_EUC_KR,
  GITG_ENCODING_EUC_TW,

  GITG_ENCODING_GB18030,
  GITG_ENCODING_GB2312,
  GITG_ENCODING_GBK,
  GITG_ENCODING_GEOSTD8,

  GITG_ENCODING_IBM_850,
  GITG_ENCODING_IBM_852,
  GITG_ENCODING_IBM_855,
  GITG_ENCODING_IBM_857,
  GITG_ENCODING_IBM_862,
  GITG_ENCODING_IBM_864,

  GITG_ENCODING_ISO_2022_JP,
  GITG_ENCODING_ISO_2022_KR,
  GITG_ENCODING_ISO_IR_111,
  GITG_ENCODING_JOHAB,
  GITG_ENCODING_KOI8_R,
  GITG_ENCODING_KOI8__R,
  GITG_ENCODING_KOI8_U,
  
  GITG_ENCODING_SHIFT_JIS,
  GITG_ENCODING_TCVN,
  GITG_ENCODING_TIS_620,
  GITG_ENCODING_UHC,
  GITG_ENCODING_VISCII,

  GITG_ENCODING_WINDOWS_1250,
  GITG_ENCODING_WINDOWS_1251,
  GITG_ENCODING_WINDOWS_1252,
  GITG_ENCODING_WINDOWS_1253,
  GITG_ENCODING_WINDOWS_1254,
  GITG_ENCODING_WINDOWS_1255,
  GITG_ENCODING_WINDOWS_1256,
  GITG_ENCODING_WINDOWS_1257,
  GITG_ENCODING_WINDOWS_1258,

  GITG_ENCODING_LAST,

  GITG_ENCODING_UTF_8,
  GITG_ENCODING_UNKNOWN
  
} GitgEncodingIndex;

static const GitgEncoding utf8_encoding =  {
	GITG_ENCODING_UTF_8,
	"UTF-8",
	N_("Unicode")
};

/* initialized in gitg_encoding_lazy_init() */
static GitgEncoding unknown_encoding = {
	GITG_ENCODING_UNKNOWN,
	NULL, 
	NULL 
};

static const GitgEncoding encodings [] = {

  { GITG_ENCODING_ISO_8859_1,
    "ISO-8859-1", N_("Western") },
  { GITG_ENCODING_ISO_8859_2,
   "ISO-8859-2", N_("Central European") },
  { GITG_ENCODING_ISO_8859_3,
    "ISO-8859-3", N_("South European") },
  { GITG_ENCODING_ISO_8859_4,
    "ISO-8859-4", N_("Baltic") },
  { GITG_ENCODING_ISO_8859_5,
    "ISO-8859-5", N_("Cyrillic") },
  { GITG_ENCODING_ISO_8859_6,
    "ISO-8859-6", N_("Arabic") },
  { GITG_ENCODING_ISO_8859_7,
    "ISO-8859-7", N_("Greek") },
  { GITG_ENCODING_ISO_8859_8,
    "ISO-8859-8", N_("Hebrew Visual") },
  { GITG_ENCODING_ISO_8859_9,
    "ISO-8859-9", N_("Turkish") },
  { GITG_ENCODING_ISO_8859_10,
    "ISO-8859-10", N_("Nordic") },
  { GITG_ENCODING_ISO_8859_13,
    "ISO-8859-13", N_("Baltic") },
  { GITG_ENCODING_ISO_8859_14,
    "ISO-8859-14", N_("Celtic") },
  { GITG_ENCODING_ISO_8859_15,
    "ISO-8859-15", N_("Western") },
  { GITG_ENCODING_ISO_8859_16,
    "ISO-8859-16", N_("Romanian") },

  { GITG_ENCODING_UTF_7,
    "UTF-7", N_("Unicode") },
  { GITG_ENCODING_UTF_16,
    "UTF-16", N_("Unicode") },
  { GITG_ENCODING_UTF_16_BE,
    "UTF-16BE", N_("Unicode") },
  { GITG_ENCODING_UTF_16_LE,
    "UTF-16LE", N_("Unicode") },
  { GITG_ENCODING_UTF_32,
    "UTF-32", N_("Unicode") },
  { GITG_ENCODING_UCS_2,
    "UCS-2", N_("Unicode") },
  { GITG_ENCODING_UCS_4,
    "UCS-4", N_("Unicode") },

  { GITG_ENCODING_ARMSCII_8,
    "ARMSCII-8", N_("Armenian") },
  { GITG_ENCODING_BIG5,
    "BIG5", N_("Chinese Traditional") },
  { GITG_ENCODING_BIG5_HKSCS,
    "BIG5-HKSCS", N_("Chinese Traditional") },
  { GITG_ENCODING_CP_866,
    "CP866", N_("Cyrillic/Russian") },

  { GITG_ENCODING_EUC_JP,
    "EUC-JP", N_("Japanese") },
  { GITG_ENCODING_EUC_JP_MS,
    "EUC-JP-MS", N_("Japanese") },
  { GITG_ENCODING_CP932,
    "CP932", N_("Japanese") },

  { GITG_ENCODING_EUC_KR,
    "EUC-KR", N_("Korean") },
  { GITG_ENCODING_EUC_TW,
    "EUC-TW", N_("Chinese Traditional") },

  { GITG_ENCODING_GB18030,
    "GB18030", N_("Chinese Simplified") },
  { GITG_ENCODING_GB2312,
    "GB2312", N_("Chinese Simplified") },
  { GITG_ENCODING_GBK,
    "GBK", N_("Chinese Simplified") },
  { GITG_ENCODING_GEOSTD8,
    "GEORGIAN-ACADEMY", N_("Georgian") }, /* FIXME GEOSTD8 ? */

  { GITG_ENCODING_IBM_850,
    "IBM850", N_("Western") },
  { GITG_ENCODING_IBM_852,
    "IBM852", N_("Central European") },
  { GITG_ENCODING_IBM_855,
    "IBM855", N_("Cyrillic") },
  { GITG_ENCODING_IBM_857,
    "IBM857", N_("Turkish") },
  { GITG_ENCODING_IBM_862,
    "IBM862", N_("Hebrew") },
  { GITG_ENCODING_IBM_864,
    "IBM864", N_("Arabic") },

  { GITG_ENCODING_ISO_2022_JP,
    "ISO-2022-JP", N_("Japanese") },
  { GITG_ENCODING_ISO_2022_KR,
    "ISO-2022-KR", N_("Korean") },
  { GITG_ENCODING_ISO_IR_111,
    "ISO-IR-111", N_("Cyrillic") },
  { GITG_ENCODING_JOHAB,
    "JOHAB", N_("Korean") },
  { GITG_ENCODING_KOI8_R,
    "KOI8R", N_("Cyrillic") },
  { GITG_ENCODING_KOI8__R,
    "KOI8-R", N_("Cyrillic") },
  { GITG_ENCODING_KOI8_U,
    "KOI8U", N_("Cyrillic/Ukrainian") },
  
  { GITG_ENCODING_SHIFT_JIS,
    "SHIFT_JIS", N_("Japanese") },
  { GITG_ENCODING_TCVN,
    "TCVN", N_("Vietnamese") },
  { GITG_ENCODING_TIS_620,
    "TIS-620", N_("Thai") },
  { GITG_ENCODING_UHC,
    "UHC", N_("Korean") },
  { GITG_ENCODING_VISCII,
    "VISCII", N_("Vietnamese") },

  { GITG_ENCODING_WINDOWS_1250,
    "WINDOWS-1250", N_("Central European") },
  { GITG_ENCODING_WINDOWS_1251,
    "WINDOWS-1251", N_("Cyrillic") },
  { GITG_ENCODING_WINDOWS_1252,
    "WINDOWS-1252", N_("Western") },
  { GITG_ENCODING_WINDOWS_1253,
    "WINDOWS-1253", N_("Greek") },
  { GITG_ENCODING_WINDOWS_1254,
    "WINDOWS-1254", N_("Turkish") },
  { GITG_ENCODING_WINDOWS_1255,
    "WINDOWS-1255", N_("Hebrew") },
  { GITG_ENCODING_WINDOWS_1256,
    "WINDOWS-1256", N_("Arabic") },
  { GITG_ENCODING_WINDOWS_1257,
    "WINDOWS-1257", N_("Baltic") },
  { GITG_ENCODING_WINDOWS_1258,
    "WINDOWS-1258", N_("Vietnamese") }
};

static void
gitg_encoding_lazy_init (void)
{
	static gboolean initialized = FALSE;
	const gchar *locale_charset;

	if (initialized)
	{
		return;
	}

	if (g_get_charset (&locale_charset) == FALSE)
	{
		unknown_encoding.charset = g_strdup (locale_charset);
	}

	initialized = TRUE;
}

const GitgEncoding *
gitg_encoding_get_from_charset (const gchar *charset)
{
	gint i;

	g_return_val_if_fail (charset != NULL, NULL);

	gitg_encoding_lazy_init ();

	if (charset == NULL)
	{
		return NULL;
	}

	if (g_ascii_strcasecmp (charset, "UTF-8") == 0)
	{
		return gitg_encoding_get_utf8 ();
	}

	i = 0;

	while (i < GITG_ENCODING_LAST)
	{
		if (g_ascii_strcasecmp (charset, encodings[i].charset) == 0)
		{
			return &encodings[i];
		}

		++i;
	}

	if (unknown_encoding.charset != NULL)
	{
		if (g_ascii_strcasecmp (charset, unknown_encoding.charset) == 0)
		{
			return &unknown_encoding;
		}
	}

	return NULL;
}

GSList *
gitg_encoding_get_candidates (void)
{
	static GSList *ret = NULL;

	if (ret == NULL)
	{
		ret = g_slist_prepend (ret,
		                       (gpointer)gitg_encoding_get_from_index (GITG_ENCODING_WINDOWS_1250));

		ret = g_slist_prepend (ret,
		                       (gpointer)gitg_encoding_get_from_index (GITG_ENCODING_ISO_8859_1));

		ret = g_slist_prepend (ret,
		                       (gpointer)gitg_encoding_get_current ());

		ret = g_slist_prepend (ret,
		                       (gpointer)gitg_encoding_get_utf8 ());
	}

	return ret;
}

const GitgEncoding *
gitg_encoding_get_from_index (gint idx)
{
	g_return_val_if_fail (idx >= 0, NULL);

	if (idx >= GITG_ENCODING_LAST)
	{
		return NULL;
	}

	gitg_encoding_lazy_init ();

	return &encodings[idx];
}

const GitgEncoding *
gitg_encoding_get_utf8 (void)
{
	gitg_encoding_lazy_init ();

	return &utf8_encoding;
}

const GitgEncoding *
gitg_encoding_get_current (void)
{
	static gboolean initialized = FALSE;
	static const GitgEncoding *locale_encoding = NULL;

	const gchar *locale_charset;

	gitg_encoding_lazy_init ();

	if (initialized != FALSE)
	{
		return locale_encoding;
	}

	if (g_get_charset (&locale_charset) == FALSE) 
	{
		g_return_val_if_fail (locale_charset != NULL, &utf8_encoding);

		locale_encoding = gitg_encoding_get_from_charset (locale_charset);
	}
	else
	{
		locale_encoding = &utf8_encoding;
	}
	
	if (locale_encoding == NULL)
	{
		locale_encoding = &unknown_encoding;
	}

	g_return_val_if_fail (locale_encoding != NULL, NULL);

	initialized = TRUE;

	return locale_encoding;
}

gchar *
gitg_encoding_to_string (const GitgEncoding* enc)
{
	g_return_val_if_fail (enc != NULL, NULL);
	
	gitg_encoding_lazy_init ();

	g_return_val_if_fail (enc->charset != NULL, NULL);

	if (enc->name != NULL)
	{
		return g_strdup_printf ("%s (%s)", _(enc->name), enc->charset);
	}
	else
	{
		if (g_ascii_strcasecmp (enc->charset, "ANSI_X3.4-1968") == 0)
		{
			return g_strdup_printf ("US-ASCII (%s)", enc->charset);
		}
		else
		{
			return g_strdup (enc->charset);
		}
	}
}

const gchar *
gitg_encoding_get_charset (const GitgEncoding* enc)
{
	g_return_val_if_fail (enc != NULL, NULL);

	gitg_encoding_lazy_init ();

	g_return_val_if_fail (enc->charset != NULL, NULL);

	return enc->charset;
}

const gchar *
gitg_encoding_get_name (const GitgEncoding* enc)
{
	g_return_val_if_fail (enc != NULL, NULL);

	gitg_encoding_lazy_init ();

	return (enc->name == NULL) ? _("Unknown") : _(enc->name);
}

/* These are to make language bindings happy. Since Encodings are
 * const, copy() just returns the same pointer and fres() doesn't
 * do nothing */

GitgEncoding *
gitg_encoding_copy (const GitgEncoding *enc)
{
	g_return_val_if_fail (enc != NULL, NULL);

	return (GitgEncoding *) enc;
}

void 
gitg_encoding_free (GitgEncoding *enc)
{
	g_return_if_fail (enc != NULL);
}

static gboolean
data_exists (GSList         *list,
	     const gpointer  data)
{
	while (list != NULL)
	{
		if (list->data == data)
			return TRUE;

		list = g_slist_next (list);
	}

	return FALSE;
}

GSList *
_gitg_encoding_strv_to_list (const gchar * const *enc_str)
{
	GSList *res = NULL;
	gchar **p;
	const GitgEncoding *enc;
	
	for (p = (gchar **)enc_str; p != NULL && *p != NULL; p++)
	{
		const gchar *charset = *p;

		if (strcmp (charset, "CURRENT") == 0)
			g_get_charset (&charset);

		g_return_val_if_fail (charset != NULL, NULL);
		enc = gitg_encoding_get_from_charset (charset);

		if (enc != NULL)
		{
			if (!data_exists (res, (gpointer)enc))
			{
				res = g_slist_prepend (res, (gpointer)enc);
			}
		}
	}

	return g_slist_reverse (res);
}

gchar **
_gitg_encoding_list_to_strv (const GSList *enc_list)
{
	GSList *l;
	GPtrArray *array;

	array = g_ptr_array_sized_new (g_slist_length ((GSList *)enc_list) + 1);

	for (l = (GSList *)enc_list; l != NULL; l = g_slist_next (l))
	{
		const GitgEncoding *enc;
		const gchar *charset;
		
		enc = (const GitgEncoding *)l->data;

		charset = gitg_encoding_get_charset (enc);
		g_return_val_if_fail (charset != NULL, NULL);

		g_ptr_array_add (array, g_strdup (charset));
	}

	g_ptr_array_add (array, NULL);

	return (gchar **)g_ptr_array_free (array, FALSE);
}

/* ex:ts=8:noet: */
