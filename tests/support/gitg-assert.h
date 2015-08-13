/*
 * This file is part of gitg
 *
 * Copyright (C) 2013 - Jesse van den Kieboom
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
 * along with gitg. If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef __GITG_ASSERT_H__
#define __GITG_ASSERT_H__

#include <glib.h>

#define gitg_test_assert_assert_no_error(error) g_assert_no_error(error)
#define gitg_test_assert_assert_streq(a, b) g_assert_cmpstr((a), ==, (b))
#define gitg_test_assert_assert_inteq(a, b) g_assert_cmpint((a), ==, (b))
#define gitg_test_assert_assert_booleq(a, b) g_assert_cmpuint((guint)(a), ==, (guint)(b))
#define gitg_test_assert_assert_uinteq(a, b) g_assert_cmpuint((a), ==, (b))
#define gitg_test_assert_assert_floateq(a, b) g_assert_cmpfloat((a), ==, (b))
#define gitg_test_assert_assert_datetime(a, b) \
	g_assert_cmpstr (g_date_time_format ((a), "%F %T %z"), \
	                 ==, \
	                 g_date_time_format ((b), "%F %T %z") \
)

#endif /* __GITG_ASSERT_H__ */

