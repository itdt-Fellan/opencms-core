package com.opencms.file.genericSql;

/*
 * File   : $Source: /alkacon/cvs/opencms/src/com/opencms/file/genericSql/Attic/CmsQueries.java,v $
 * Date   : $Date: 2001/06/22 16:00:44 $
 * Version: $Revision: 1.41 $
 *
 * Copyright (C) 2000  The OpenCms Group
 *
 * This File is part of OpenCms -
 * the Open Source Content Mananagement System
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General public  License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General public  License for more details.
 *
 * For further information about OpenCms, please see the
 * OpenCms Website: http://www.opencms.com
 *
 * You should have received a copy of the GNU General public  License
 * long with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

import com.opencms.core.*;
import java.util.*;

/**
 * This interface is defines all queries used in the DB-Access class.
 * @author Michael Emmerich
 *
 * @version $Revision: 1.41 $ $Date: 2001/06/22 16:00:44 $
 */
public class CmsQueries
{
    private static Properties m_queries = null;
    /**
     * CmsQueries constructor comment.
     */
    public CmsQueries() {
        if(m_queries == null) {
            m_queries = new Properties();
            try {
                m_queries.load(getClass().getClassLoader().getResourceAsStream("com/opencms/file/genericSql/query.properties"));
            } catch(NullPointerException exc) {
                if(A_OpenCms.isLogging() && I_CmsLogChannels.C_PREPROCESSOR_IS_LOGGING) {
                    A_OpenCms.log(I_CmsLogChannels.C_OPENCMS_CRITICAL, "[CmsQueries] cannot get com/opencms/file/genericSql/query.properties");
                }
            } catch(java.io.IOException exc) {
                if(A_OpenCms.isLogging() && I_CmsLogChannels.C_PREPROCESSOR_IS_LOGGING) {
                    A_OpenCms.log(I_CmsLogChannels.C_OPENCMS_CRITICAL, "[CmsQueries] cannot get com/opencms/file/genericSql/query.properties");
                }
            }
        }
    }

    /**
     * Get the value for the query name
     *
     * @param queryName the name of the property
     * @return The value of the property
     */
    public String get(String queryName){
        if(m_queries == null) {
            m_queries = new Properties();
            try {
                m_queries.load(getClass().getClassLoader().getResourceAsStream("com/opencms/file/genericSql/query.properties"));
            } catch(NullPointerException exc) {
                if(A_OpenCms.isLogging() && I_CmsLogChannels.C_PREPROCESSOR_IS_LOGGING) {
                    A_OpenCms.log(I_CmsLogChannels.C_OPENCMS_CRITICAL, "[CmsQueries] cannot get com/opencms/file/genericSql/query.properties");
                }
            } catch(java.io.IOException exc) {
                if(A_OpenCms.isLogging() && I_CmsLogChannels.C_PREPROCESSOR_IS_LOGGING) {
                    A_OpenCms.log(I_CmsLogChannels.C_OPENCMS_CRITICAL, "[CmsQueries] cannot get com/opencms/file/genericSql/query.properties");
                }
            }
        }
        String value = m_queries.getProperty(queryName);
        return value;
    }
}
