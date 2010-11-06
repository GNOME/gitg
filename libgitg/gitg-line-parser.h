/*
 * gitg-line-parser.h
 * This file is part of gitg
 *
 * Copyright (C) 2010 - Jesse van den Kieboom
 *
 * gitg is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * gitg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with gitg; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, 
 * Boston, MA  02110-1301  USA
 */

#ifndef __GITG_LINE_PARSER_H__
#define __GITG_LINE_PARSER_H__

#include <gio/gio.h>

G_BEGIN_DECLS

#define GITG_TYPE_LINE_PARSER			(gitg_line_parser_get_type ())
#define GITG_LINE_PARSER(obj)			(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_LINE_PARSER, GitgLineParser))
#define GITG_LINE_PARSER_CONST(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_LINE_PARSER, GitgLineParser const))
#define GITG_LINE_PARSER_CLASS(klass)		(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_LINE_PARSER, GitgLineParserClass))
#define GITG_IS_LINE_PARSER(obj)		(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_LINE_PARSER))
#define GITG_IS_LINE_PARSER_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_LINE_PARSER))
#define GITG_LINE_PARSER_GET_CLASS(obj)		(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_LINE_PARSER, GitgLineParserClass))

typedef struct _GitgLineParser		GitgLineParser;
typedef struct _GitgLineParserClass	GitgLineParserClass;
typedef struct _GitgLineParserPrivate	GitgLineParserPrivate;

struct _GitgLineParser
{
	/*< private >*/
	GObject parent;

	GitgLineParserPrivate *priv;
};

struct _GitgLineParserClass
{
	/*< private >*/
	GObjectClass parent_class;
};

GType gitg_line_parser_get_type (void) G_GNUC_CONST;

GitgLineParser *gitg_line_parser_new (guint         buffer_size,
                                      gboolean      preserve_line_endings);

void gitg_line_parser_parse (GitgLineParser *parser,
                             GInputStream   *stream,
                             GCancellable   *cancellable);

G_END_DECLS

#endif /* __GITG_LINE_PARSER_H__ */
