/*
 * gitg-line-parser.c
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

#include "gitg-line-parser.h"

#define GITG_LINE_PARSER_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_LINE_PARSER, GitgLineParserPrivate))

struct _GitgLineParserPrivate
{
	gchar *rest_buffer;
	gsize rest_buffer_size;

	gchar **lines;
	guint buffer_size;

	gchar *read_buffer;

	gboolean preserve_line_endings;
};

enum
{
	LINES,
	DONE,
	NUM_SIGNALS
};

G_DEFINE_TYPE (GitgLineParser, gitg_line_parser, G_TYPE_OBJECT)

enum
{
	PROP_0,
	PROP_BUFFER_SIZE,
	PROP_PRESERVE_LINE_ENDINGS
};

static guint signals[NUM_SIGNALS] = {0,};

typedef struct
{
	GitgLineParser *parser;
	GInputStream *stream;
	GCancellable *cancellable;
} AsyncData;

static AsyncData *
async_data_new (GitgLineParser *parser,
                GInputStream   *stream,
                GCancellable   *cancellable)
{
	AsyncData *data;

	data = g_slice_new (AsyncData);
	data->parser = parser;
	data->stream = stream;
	data->cancellable = g_object_ref (cancellable);

	return data;
}

static void
async_data_free (AsyncData *data)
{
	g_object_unref (data->cancellable);
	g_slice_free (AsyncData, data);
}

static void
free_lines (GitgLineParser *stream)
{
	gint i = 0;

	while (stream->priv->lines[i])
	{
		g_free (stream->priv->lines[i++]);
	}

	stream->priv->lines[0] = NULL;
}

static void
gitg_line_parser_finalize (GObject *object)
{
	GitgLineParser *stream;

	stream = GITG_LINE_PARSER (object);

	free_lines (stream);

	g_slice_free1 (sizeof (gchar *) * (stream->priv->buffer_size + 1), stream->priv->lines);
	g_slice_free1 (sizeof (gchar) * (stream->priv->buffer_size + 1), stream->priv->read_buffer);

	G_OBJECT_CLASS (gitg_line_parser_parent_class)->finalize (object);
}

static const gchar *
find_newline (const gchar  *ptr,
              const gchar  *end,
              const gchar **line_end)
{

	while (ptr < end)
	{
		gunichar c;

		c = g_utf8_get_char (ptr);

		if (c == '\n')
		{
			/* That's it */
			*line_end = g_utf8_next_char (ptr);
			return ptr;
		}
		else if (c == '\r')
		{
			gchar *next;

			next = g_utf8_next_char (ptr);

			if (next < end)
			{
				gunichar n = g_utf8_get_char (next);

				if (n == '\n')
				{
					/* Consume both! */
					*line_end = g_utf8_next_char (next);
					return ptr;
				}
				else
				{
					/* That's it! */
					*line_end = next;
					return ptr;
				}
			}
			else
			{
				/* Need to save it, it might come later... */
				break;
			}
		}

		ptr = g_utf8_next_char (ptr);
	}

	return NULL;
}

static void
parse_lines (GitgLineParser *stream,
             const gchar    *buffer,
             gssize          size)
{
	gchar const *ptr;
	gchar const *newline = NULL;
	gint i = 0;
	gchar *all = NULL;
	gchar const *end;

	if (stream->priv->rest_buffer_size > 0)
	{
		GString *str = g_string_sized_new (stream->priv->rest_buffer_size + size);

		g_string_append_len (str, stream->priv->rest_buffer, stream->priv->rest_buffer_size);
		g_string_append_len (str, buffer, size);

		all = g_string_free (str, FALSE);
		size += stream->priv->rest_buffer_size;

		g_free (stream->priv->rest_buffer);
		stream->priv->rest_buffer = NULL;
		stream->priv->rest_buffer_size = 0;

		ptr = all;
	}
	else
	{
		ptr = buffer;
	}

	const gchar *line_end;
	end = ptr + size;

	while ((newline = find_newline (ptr, end, &line_end)))
	{
		if (stream->priv->preserve_line_endings)
		{
			stream->priv->lines[i++] = g_strndup (ptr, line_end - ptr);
		}
		else
		{
			stream->priv->lines[i++] = g_strndup (ptr, newline - ptr);
		}

		ptr = line_end;

		if (i == stream->priv->buffer_size)
		{
			break;
		}
	}

	if (ptr < end)
	{
		stream->priv->rest_buffer_size = end - ptr;
		stream->priv->rest_buffer = g_strndup (ptr, stream->priv->rest_buffer_size);
	}

	stream->priv->lines[i] = NULL;

	g_signal_emit (stream, signals[LINES], 0, stream->priv->lines);

	g_free (all);
}

static void
emit_rest (GitgLineParser *stream)
{
	if (stream->priv->rest_buffer_size > 0)
	{
		if (!stream->priv->preserve_line_endings &&
		     stream->priv->rest_buffer[stream->priv->rest_buffer_size - 1] == '\r')
		{
			stream->priv->rest_buffer[stream->priv->rest_buffer_size - 1] = '\0';
		}

		gchar *b[] = {stream->priv->rest_buffer, NULL};

		g_signal_emit (stream, signals[LINES], 0, b);

		g_free (stream->priv->rest_buffer);
		stream->priv->rest_buffer = NULL;
		stream->priv->rest_buffer_size = 0;
	}
}

static void
parser_done (AsyncData *data,
             GError    *error)
{
	if (!error)
	{
		emit_rest (data->parser);
	}

	g_signal_emit (data->parser, signals[DONE], 0, error);

	async_data_free (data);
}

static void
gitg_line_parser_set_property (GObject      *object,
                                      guint         prop_id,
                                      const GValue *value,
                                      GParamSpec   *pspec)
{
	GitgLineParser *self = GITG_LINE_PARSER (object);

	switch (prop_id)
	{
		case PROP_BUFFER_SIZE:
			self->priv->buffer_size = g_value_get_uint (value);
		break;
		case PROP_PRESERVE_LINE_ENDINGS:
			self->priv->preserve_line_endings = g_value_get_boolean (value);
		break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
		break;
	}
}

static void
gitg_line_parser_get_property (GObject    *object,
                                      guint       prop_id,
                                      GValue     *value,
                                      GParamSpec *pspec)
{
	GitgLineParser *self = GITG_LINE_PARSER (object);

	switch (prop_id)
	{
		case PROP_BUFFER_SIZE:
			g_value_set_uint (value, self->priv->buffer_size);
		break;
		case PROP_PRESERVE_LINE_ENDINGS:
			g_value_set_boolean (value, self->priv->preserve_line_endings);
		break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
		break;
	}
}

static void
gitg_line_parser_constructed (GObject *object)
{
	GitgLineParser *stream;

	stream = GITG_LINE_PARSER (object);

	stream->priv->lines = g_slice_alloc (sizeof (gchar *) * (stream->priv->buffer_size + 1));
	stream->priv->lines[0] = NULL;

	stream->priv->read_buffer = g_slice_alloc (sizeof (gchar) * (stream->priv->buffer_size + 1));
}

static void start_read_lines (AsyncData *data);

static void
read_ready (GInputStream *stream,
            GAsyncResult *result,
            AsyncData    *data)
{
	gssize read;
	GError *error = NULL;

	read = g_input_stream_read_finish (stream, result, &error);

	if (g_cancellable_is_cancelled (data->cancellable))
	{
		if (error)
		{
			g_error_free (error);
		}

		async_data_free (data);
		return;
	}

	if (read == -1)
	{
		parser_done (data, error);

		if (error)
		{
			g_error_free (error);
		}
	}
	else if (read == 0)
	{
		parser_done (data, NULL);
	}
	else
	{
		data->parser->priv->read_buffer[read] = '\0';

		parse_lines (data->parser,
		             data->parser->priv->read_buffer,
		             read);

		start_read_lines (data);
	}
}

static void
start_read_lines (AsyncData *data)
{
	g_input_stream_read_async (data->stream,
	                           data->parser->priv->read_buffer,
	                           data->parser->priv->buffer_size,
	                           G_PRIORITY_DEFAULT,
	                           data->cancellable,
	                           (GAsyncReadyCallback)read_ready,
	                           data);
}

static void
gitg_line_parser_class_init (GitgLineParserClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS (klass);

	object_class->finalize = gitg_line_parser_finalize;
	object_class->constructed = gitg_line_parser_constructed;

	object_class->get_property = gitg_line_parser_get_property;
	object_class->set_property = gitg_line_parser_set_property;

	g_type_class_add_private (object_class, sizeof(GitgLineParserPrivate));

	signals[LINES] =
		g_signal_new ("lines",
		              G_OBJECT_CLASS_TYPE (object_class),
		              G_SIGNAL_RUN_LAST,
		              0,
		              NULL,
		              NULL,
		              g_cclosure_marshal_VOID__POINTER,
		              G_TYPE_NONE,
		              1,
		              G_TYPE_POINTER);

	signals[DONE] =
		g_signal_new ("done",
		              G_OBJECT_CLASS_TYPE (object_class),
		              G_SIGNAL_RUN_LAST,
		              0,
		              NULL,
		              NULL,
		              g_cclosure_marshal_VOID__BOXED,
		              G_TYPE_NONE,
		              1,
		              G_TYPE_ERROR);

	g_object_class_install_property (object_class,
	                                 PROP_BUFFER_SIZE,
	                                 g_param_spec_uint ("buffer-size",
	                                                    "Buffer size",
	                                                    "Buffer Size",
	                                                    1,
	                                                    G_MAXUINT,
	                                                    100,
	                                                    G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY));

	g_object_class_install_property (object_class,
	                                 PROP_PRESERVE_LINE_ENDINGS,
	                                 g_param_spec_boolean ("preserve-line-endings",
	                                                       "Preserve line endings",
	                                                       "Preserve Line Endings",
	                                                       FALSE,
	                                                       G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY));
}

static void
gitg_line_parser_init (GitgLineParser *self)
{
	self->priv = GITG_LINE_PARSER_GET_PRIVATE (self);
}

GitgLineParser *
gitg_line_parser_new (guint    buffer_size,
                      gboolean preserve_line_endings)
{
	return g_object_new (GITG_TYPE_LINE_PARSER,
	                     "buffer-size", buffer_size,
	                     "preserve-line-endings", preserve_line_endings,
	                     NULL);
}

void
gitg_line_parser_parse (GitgLineParser *parser,
                        GInputStream   *stream,
                        GCancellable   *cancellable)
{
	AsyncData *data;

	g_return_if_fail (GITG_IS_LINE_PARSER (parser));
	g_return_if_fail (G_IS_INPUT_STREAM (stream));
	g_return_if_fail (cancellable == NULL || G_IS_CANCELLABLE (cancellable));

	data = async_data_new (parser, stream, cancellable);
	start_read_lines (data);
}
