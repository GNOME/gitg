/*
 * Copyright (C) 1997, 1998, 1999, 2000 Free Software Foundation
 * All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.

 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */
/*
 * Handles all of the internationalization configuration options.
 * Author: Tom Tromey <tromey@creche.cygnus.com>
 *
 * This is a modified version of gtksourceview-i18n.h
 */

#ifndef __PEAS_18N_H__
#define __PEAS_18N_H__

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <glib.h>

G_BEGIN_DECLS

#ifdef ENABLE_NLS
#    include <libintl.h>
#    undef _
#    define _(String) _gitg_gettext (String)
#    undef N_
#    ifdef gettext_noop
#        define N_(String) gettext_noop (String)
#    else
#        define N_(String) (String)
#    endif
#else
/* Stubs that do something close enough.  */
#    undef textdomain
#    define textdomain(String) (String)
#    undef gettext
#    define gettext(String) (String)
#    undef dgettext
#    define dgettext(Domain,Message) (Message)
#    undef dcgettext
#    define dcgettext(Domain,Message,Type) (Message)
#    undef bindtextdomain
#    define bindtextdomain(Domain,Directory) (Domain)
#    undef bind_textdomain_codeset
#    define bind_textdomain_codeset(Domain,CodeSet) (Domain)
#    undef _
#    define _(String) (String)
#    undef N_
#    define N_(String) (String)
#endif

const gchar *_gitg_gettext (const char *msgid) G_GNUC_FORMAT(1);

G_END_DECLS

#endif /* __PEAS_I18N_H__ */
