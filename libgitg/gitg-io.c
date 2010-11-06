/*
 * gitg-io.c
 * This file is part of gitg
 *
 * Copyright (C) 2010 - Jesse van den Kieboom
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
 * Foundation, Inc., 51 Franklin St, Fifth Floor, 
 * Boston, MA  02110-1301  USA
 */

#include "gitg-io.h"

#define GITG_IO_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_IO, GitgIOPrivate))

struct _GitgIOPrivate
{
	GInputStream *input;
	GOutputStream *output;

	gint exit_status;

	guint cancelled : 1;
	guint running : 1;
};

enum
{
	PROP_0,

	PROP_INPUT,
	PROP_OUTPUT,
	PROP_CANCELLED,
	PROP_EXIT_STATUS,
	PROP_RUNNING
};

enum
{
	BEGIN,
	END,
	NUM_SIGNALS
};

G_DEFINE_TYPE (GitgIO, gitg_io, G_TYPE_OBJECT)

static guint signals[NUM_SIGNALS] = {0,};

static void
gitg_io_finalize (GObject *object)
{
	G_OBJECT_CLASS (gitg_io_parent_class)->finalize (object);
}

static void
gitg_io_dispose (GObject *object)
{
	GitgIO *io;

	io = GITG_IO (object);

	gitg_io_close (io);

	G_OBJECT_CLASS (gitg_io_parent_class)->dispose (object);
}

static void
gitg_io_set_property (GObject      *object,
                      guint         prop_id,
                      const GValue *value,
                      GParamSpec   *pspec)
{
	GitgIO *self = GITG_IO (object);

	switch (prop_id)
	{
		case PROP_INPUT:
			gitg_io_set_input (self, g_value_get_object (value));
			break;
		case PROP_OUTPUT:
			gitg_io_set_output (self, g_value_get_object (value));
			break;
		case PROP_CANCELLED:
			gitg_io_set_cancelled (self, g_value_get_boolean (value));
			break;
		case PROP_EXIT_STATUS:
			gitg_io_set_exit_status (self, g_value_get_int (value));
			break;
		case PROP_RUNNING:
			gitg_io_set_running (self, g_value_get_boolean (value));
			break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
		break;
	}
}

static void
gitg_io_get_property (GObject    *object,
                      guint       prop_id,
                      GValue     *value,
                      GParamSpec *pspec)
{
	GitgIO *self = GITG_IO (object);

	switch (prop_id)
	{
		case PROP_INPUT:
			g_value_set_object (value, self->priv->input);
			break;
		case PROP_OUTPUT:
			g_value_set_object (value, self->priv->output);
			break;
		case PROP_CANCELLED:
			g_value_set_boolean (value, self->priv->cancelled);
			break;
		case PROP_EXIT_STATUS:
			g_value_set_int (value, self->priv->exit_status);
			break;
		case PROP_RUNNING:
			g_value_set_boolean (value, self->priv->running);
			break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
		break;
	}
}

static void
gitg_io_cancel_impl (GitgIO *io)
{
	io->priv->cancelled = TRUE;
}

static void
gitg_io_begin_impl (GitgIO *io)
{
	gitg_io_set_running (io, TRUE);
}

static void
gitg_io_end_impl (GitgIO *io,
                  GError *error)
{
	gitg_io_set_running (io, FALSE);
}

static void
gitg_io_class_init (GitgIOClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS (klass);

	object_class->finalize = gitg_io_finalize;
	object_class->dispose = gitg_io_dispose;

	object_class->get_property = gitg_io_get_property;
	object_class->set_property = gitg_io_set_property;

	klass->cancel = gitg_io_cancel_impl;
	klass->begin = gitg_io_begin_impl;
	klass->end = gitg_io_end_impl;

	g_object_class_install_property (object_class,
	                                 PROP_INPUT,
	                                 g_param_spec_object ("input",
	                                                      "Input",
	                                                      "Input",
	                                                      G_TYPE_INPUT_STREAM,
	                                                      G_PARAM_READWRITE));

	g_object_class_install_property (object_class,
	                                 PROP_OUTPUT,
	                                 g_param_spec_object ("output",
	                                                      "Output",
	                                                      "Output",
	                                                      G_TYPE_OUTPUT_STREAM,
	                                                      G_PARAM_READWRITE));

	g_object_class_install_property (object_class,
	                                 PROP_CANCELLED,
	                                 g_param_spec_boolean ("cancelled",
	                                                       "Cancelled",
	                                                       "Cancelled",
	                                                       FALSE,
	                                                       G_PARAM_READWRITE | G_PARAM_CONSTRUCT));

	g_object_class_install_property (object_class,
	                                 PROP_EXIT_STATUS,
	                                 g_param_spec_int ("exit-status",
	                                                   "Exit status",
	                                                   "Exit Status",
	                                                   G_MININT,
	                                                   G_MAXINT,
	                                                   0,
	                                                   G_PARAM_READWRITE));

	g_object_class_install_property (object_class,
	                                 PROP_RUNNING,
	                                 g_param_spec_boolean ("running",
	                                                       "Running",
	                                                       "Running",
	                                                       FALSE,
	                                                       G_PARAM_READWRITE));

	signals[BEGIN] =
		g_signal_new ("begin",
		              G_TYPE_FROM_CLASS (klass),
		              G_SIGNAL_RUN_FIRST,
		              G_STRUCT_OFFSET (GitgIOClass, begin),
		              NULL,
		              NULL,
		              g_cclosure_marshal_VOID__VOID,
		              G_TYPE_NONE,
		              0);

	signals[END] =
		g_signal_new ("end",
		              G_TYPE_FROM_CLASS (klass),
		              G_SIGNAL_RUN_FIRST,
		              G_STRUCT_OFFSET (GitgIOClass, end),
		              NULL,
		              NULL,
		              g_cclosure_marshal_VOID__BOXED,
		              G_TYPE_NONE,
		              1,
		              G_TYPE_ERROR);

	g_type_class_add_private (object_class, sizeof (GitgIOPrivate));
}

static void
gitg_io_init (GitgIO *self)
{
	self->priv = GITG_IO_GET_PRIVATE (self);
}

GitgIO *
gitg_io_new ()
{
	return g_object_new (GITG_TYPE_IO, NULL);
}

void
gitg_io_begin (GitgIO *io)
{
	g_return_if_fail (GITG_IS_IO (io));

	if (!io->priv->running)
	{
		g_signal_emit (io, signals[BEGIN], 0);
	}
}

void
gitg_io_end (GitgIO *io,
             GError *error)
{
	g_return_if_fail (GITG_IS_IO (io));

	if (io->priv->running)
	{
		g_signal_emit (io, signals[END], 0, error);
	}
}

void
gitg_io_cancel (GitgIO *io)
{
	if (GITG_IO_GET_CLASS (io)->cancel)
	{
		GITG_IO_GET_CLASS (io)->cancel (io);
	}
}

gboolean
gitg_io_get_cancelled (GitgIO *io)
{
	g_return_val_if_fail (GITG_IS_IO (io), FALSE);

	return io->priv->cancelled;
}

void
gitg_io_set_cancelled (GitgIO   *io,
                       gboolean  cancelled)
{
	g_return_if_fail (GITG_IS_IO (io));

	if (io->priv->cancelled != cancelled)
	{
		io->priv->cancelled = cancelled;
		g_object_notify (G_OBJECT (io), "cancelled");
	}
}

void
gitg_io_set_output (GitgIO        *io,
                    GOutputStream *stream)
{
	g_return_if_fail (GITG_IS_IO (io));
	g_return_if_fail (G_IS_OUTPUT_STREAM (stream));

	if (io->priv->output)
	{
		g_object_unref (io->priv->output);
		io->priv->output = NULL;
	}

	if (stream)
	{
		io->priv->output = g_object_ref (stream);
	}
}

void
gitg_io_set_input (GitgIO       *io,
                   GInputStream *stream)
{
	g_return_if_fail (GITG_IS_IO (io));
	g_return_if_fail (G_IS_INPUT_STREAM (stream));

	if (io->priv->input)
	{
		g_object_unref (io->priv->input);
		io->priv->input = NULL;
	}

	if (stream)
	{
		io->priv->input = g_object_ref (stream);
	}
}

GInputStream *
gitg_io_get_input (GitgIO *io)
{
	g_return_val_if_fail (GITG_IS_IO (io), NULL);
	return io->priv->input;
}

GOutputStream *
gitg_io_get_output (GitgIO *io)
{
	g_return_val_if_fail (GITG_IS_IO (io), NULL);
	return io->priv->output;
}

void
gitg_io_close (GitgIO *io)
{
	g_return_if_fail (GITG_IS_IO (io));

	if (io->priv->input)
	{
		g_input_stream_close (io->priv->input, NULL, NULL);

		g_object_unref (io->priv->input);
		io->priv->input = NULL;
	}

	if (io->priv->output)
	{
		g_output_stream_close (io->priv->output, NULL, NULL);

		g_object_unref (io->priv->output);
		io->priv->output = NULL;
	}
}

gint
gitg_io_get_exit_status (GitgIO *io)
{
	g_return_val_if_fail (GITG_IS_IO (io), 0);

	return io->priv->exit_status;
}

void
gitg_io_set_exit_status (GitgIO *io,
                         gint    exit_status)
{
	g_return_if_fail (GITG_IS_IO (io));

	if (io->priv->exit_status != exit_status)
	{
		io->priv->exit_status = exit_status;
		g_object_notify (G_OBJECT (io), "exit-status");
	}
}

gboolean
gitg_io_get_running (GitgIO *io)
{
	g_return_val_if_fail (GITG_IS_IO (io), FALSE);

	return io->priv->running;
}

void
gitg_io_set_running (GitgIO   *io,
                     gboolean  running)
{
	g_return_if_fail (GITG_IS_IO (io));

	if (io->priv->running != running)
	{
		io->priv->running = running;

		if (running)
		{
			io->priv->cancelled = FALSE;
		}

		g_object_notify (G_OBJECT (io), "running");
	}
}
