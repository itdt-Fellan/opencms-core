/*
 * File   : $Source: /alkacon/cvs/opencms/src/com/opencms/util/Attic/Utils.java,v $
 * Date   : $Date: 2000/03/28 16:06:20 $
 * Version: $Revision: 1.9 $
 *
 * Copyright (C) 2000  The OpenCms Group 
 * 
 * This File is part of OpenCms -
 * the Open Source Content Mananagement System
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * For further information about OpenCms, please see the
 * OpenCms Website: http://www.opencms.com
 * 
 * You should have received a copy of the GNU General Public License
 * long with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

package com.opencms.util;

import com.opencms.file.*;
import com.opencms.core.*;

import java.util.*;

/**
 * This is a general helper class.
 * 
 * @author Andreas Schouten
 * @version $Revision: 1.9 $ $Date: 2000/03/28 16:06:20 $
 */
public class Utils implements I_CmsConstants, I_CmsLogChannels {
	/** Constant for sorting files upward by name */
    public static final int C_SORT_NAME_UP = 1;
    
	/** Constant for sorting files downward by name */
    public static final int C_SORT_NAME_DOWN = 2;

    /** Constant for sorting files upward by lastmodified date */
    public static final int C_SORT_LASTMODIFIED_UP = 3;
  
    /** Constant for sorting files downward by lastmodified date */
    public static final int C_SORT_LASTMODIFIED_DOWN = 4;
    
    /**
	 * This method splits a overgiven string into substrings. 
	 * 
	 * @param toSplit the String to split.
	 * @param at the delimeter.
	 * 
	 * @return an Array of Strings.
	 */
	public static final String[] split(String toSplit, String at) {
		Vector parts = new Vector();
		int index = 0;
		int nextIndex = toSplit.indexOf(at);
		
		while(nextIndex != -1) {
			parts.addElement( (Object) toSplit.substring(index, nextIndex) );
			index = nextIndex + at.length();
			nextIndex = toSplit.indexOf(at, index);
		}
		parts.addElement( (Object) toSplit.substring(index) );
		
		String partsArray[] = new String[parts.size()];
		parts.copyInto((Object[]) partsArray );
		return(partsArray);
	}


     /**
      * Gets a formated time string form a long time value.
      * @param time The time value as a long.
      * @return Formated time string.
      */
     public static String getNiceDate(long time) {
         StringBuffer niceTime=new StringBuffer();
         
         GregorianCalendar cal = new GregorianCalendar();
         cal.setTime(new Date(time));
         String day="0"+new Integer(cal.get(Calendar.DAY_OF_MONTH)).intValue();        
         String month="0"+new Integer(cal.get(Calendar.MONTH)+1).intValue(); 
         String year=new Integer(cal.get(Calendar.YEAR)).toString();
         String hour="0"+new Integer(cal.get(Calendar.HOUR)+12*cal.get(Calendar.AM_PM)).intValue();   
         String minute="0"+new Integer(cal.get(Calendar.MINUTE));   
         if (day.length()==3) {
             day=day.substring(1,3);
         }
         if (month.length()==3) {
             month=month.substring(1,3);
         }
         if (hour.length()==3) {
             hour=hour.substring(1,3);
         }
         if (minute.length()==3) {
             minute=minute.substring(1,3);
         }
         niceTime.append(day+".");
         niceTime.append(month+".");  
         niceTime.append(year+" ");
         niceTime.append(hour+":");
         niceTime.append(minute);
         return niceTime.toString();
     }

     /**
      * Gets a formated time string form a long time value.
      * @param time The time value as a long.
      * @return Formated time string.
      */
     public static String getNiceShortDate(long time) {
         StringBuffer niceTime=new StringBuffer();
         
         GregorianCalendar cal = new GregorianCalendar();
         cal.setTime(new Date(time));
         String day="0"+new Integer(cal.get(Calendar.DAY_OF_MONTH)).intValue();        
         String month="0"+new Integer(cal.get(Calendar.MONTH)+1).intValue(); 
         String year=new Integer(cal.get(Calendar.YEAR)).toString();
         if (day.length()==3) {
             day=day.substring(1,3);
         }
         if (month.length()==3) {
             month=month.substring(1,3);
         }
         niceTime.append(day+".");
         niceTime.append(month+".");  
         niceTime.append(year);
         return niceTime.toString();
     }
     
     /**
      * Sorts a Vector of CmsFile objects according to an included sorting method.
      * @param cms Cms Object for accessign files.
      * @param unsortedFiles Vector containing a list of unsorted files
      * @param sorting The sorting method to be used.
      * @return Vector of sorted CmsFile objects
      */
     public static Vector sort(A_CmsObject cms, Vector unsortedFiles, int sorting){
         Vector v=new Vector();
     
         Enumeration enu =unsortedFiles.elements();
         CmsFile [] field=new CmsFile[unsortedFiles.size()];
         CmsFile file;
         String docloader;
         
         int max=0;
         try{
             
            // create an array with all unsorted files in it. This arre is later sorted in with
            // the sorting algorithem.
            while (enu.hasMoreElements()) {
                file=(CmsFile)enu.nextElement();
                field[max]=file;
                max++;
            }
         
            // Sorting algorithm
            // This method uses an insertion sort algorithem
            int in,out;
		    int nElem = max;
		    for(out=1; out < nElem; out++){
			    CmsFile temp= field[out];
			    in = out;
                while (in >0 && compare(cms,sorting,field[in-1],temp)) {
                    field[in]=field[in-1];
				    --in;
			    }
			    field[in]=temp;
			}
    
            // take sorted array and create a new vector of files out of it
            for (int i=0;i<max;i++) {           
                v.addElement(field[i]);
            }
                                     
         }catch (Exception e){
            if(A_OpenCms.isLogging()) {               
                 A_OpenCms.log(C_OPENCMS_CRITICAL, "[Utils] :"+e.toString());
            }
        }
         return v;
     }
     
     /**
      * This method makes the sorting desicion for the creation of index and archive pages,
      * depending on the sorting method to be used.
      * @param cms Cms Object for accessign files.
      * @param sorting The sorting method to be used.
      * @param fileA One of the two CmsFile objects to be compared.
      * @param fileB The second of the two CmsFile objects to be compared.
      * @return <code>true</code> or <code>false</code>, depending if the two file objects have to be sorted.
      * @exception CmsException Is thrown when file access failed.
      * 
      */
     private static boolean compare(A_CmsObject cms, int sorting, CmsFile fileA, CmsFile fileB)
         throws CmsException {
       
         boolean cmp=false;
         
         String titleA = fileA.getName();
         String titleB = fileB.getName();
         long lastModifiedA=fileA.getDateLastModified();
         long lastModifiedB=fileB.getDateLastModified();
         
         switch(sorting) {
         case C_SORT_NAME_UP:                      
             cmp = (titleA.compareTo(titleB) > 0);
             break;
         case C_SORT_NAME_DOWN:
             cmp = (titleB.compareTo(titleA) > 0 );
             break;
         case C_SORT_LASTMODIFIED_UP:
             cmp=( lastModifiedA > lastModifiedB);
             break;
         case C_SORT_LASTMODIFIED_DOWN:
             cmp=( lastModifiedA < lastModifiedB);
             break;
         default:
             cmp = false;    
         }
         return cmp;
     }              
	 
	 /**
	  * Returns a string representation of the full name of a user.
	  * @param user The user to get the full name from
	  * @return a string representation of the user fullname.
	  */
	 public static String getFullName(A_CmsUser user) {
		 String retValue = "";
		 if(user != null) {
			 retValue += user.getFirstname() + " ";
			 retValue += user.getLastname() + " (";
			 retValue += user.getName() + ")";
		 }
		 return retValue;
	 }
}
