!
! License-Identifier: GPL
!
! Copyright (C) 2006 The Yambo Team
!
! Authors (see AUTHORS file for details): AM DS
!
module IO_m
 !
 use pars,       ONLY:SP,DP,lchlen,schlen,max_io_units,max_io_vars_open,max_active_sections
#if !defined _io_lib
 use C_driver,   ONLY:code_version,code_revision,code_GPL_revision
#endif
 use netcdf
 !
 implicit none
 !
 ! World known variables
 !
 real(SP):: db_alat(3)
 !
 ! The serial number is assigned by the YAMBO interfaces.
 ! It defines uniquely the db1/wf/kb_pp databases.
 !
 integer :: serial_number
 !
 logical :: IO_write
 logical :: IO_read
 !
 ! Global DB I/O control string
 !
 character(lchlen) :: DBs_IO_control_string = "none"
 logical           :: io_DIP
 logical           :: io_RESPONSE
 logical           :: io_MULTIPOLE
 logical           :: io_HF
 logical           :: io_COLLs
 logical           :: io_OBSERVABLES
 logical           :: io_CARRIERs
 logical           :: io_GF
 logical           :: io_SC
 logical           :: io_BS_K
 logical           :: io_SCREEN
 !
 character(lchlen) :: DBs_FRAG_control_string = "none"
 logical           :: frag_DIP
 logical           :: frag_DG
 logical           :: frag_RESPONSE
 logical           :: frag_MULTIPOLE
 logical           :: frag_WF
 logical           :: frag_QINDX
 logical           :: frag_HF
 logical           :: frag_SC
 logical           :: frag_RT
 logical           :: frag_ELPH
 logical           :: frag_BS_K
 logical           :: frag_SCREEN
 !
 ! Actions
 !
 integer, parameter:: RD_CL=1,OP_RD_CL=2,OP_WR_CL=3,OP_APP_CL=4,OP_RD=5,OP_APP=6,&
&                     OP_WR=7,RD=8,WR=9,RD_CL_IF_END=10,WR_CL=11,WR_CL_IF_END=12,   &
&                     OP_IF_START_RD_CL_IF_END=13,OP_IF_START_WR_CL_IF_END=14,&
&                     OP_IF_START_APP_CL_IF_END=15
 !
 ! Modes
 !
 integer, parameter:: DUMP=31,VERIFY=32
 !
 ! COM
 !
 integer, parameter:: REP=41,LOG=42,NONE=43
 real(SP),parameter:: NO_VAR=-246824._SP
 !
 ! I/O
 !
 integer, parameter:: MASTER=51,ALL=52
 !
 ! I/O errors
 !
 integer, parameter:: IO_NO_DATABASE=-1,IO_INCOMPATIBLE_VAR=-2,IO_GENERIC_ERROR=-3,&
&                     IO_NO_BINDING_ERROR=-4,IO_NO_ERROR=0,IO_OUTDATED_DB=-5,IO_NOT_ALLOWED=-6
 !
 ! I/O create / read / write modes
 !
 integer, parameter:: IO_WRITE_MODE =ior(nf90_share,nf90_write)
 integer, parameter:: IO_READ_MODE  =               nf90_nowrite
 !
#if defined _NC_CLASSIC
 integer, parameter:: IO_CREATE_MODE=ior(nf90_share,nf90_classic_model)
#elif defined _HDF5_IO
 integer, parameter:: IO_CREATE_MODE=ior(nf90_share,nf90_netcdf4)
#else
 integer, parameter:: IO_CREATE_MODE=ior(nf90_share,nf90_64bit_offset)
#endif
 !
#if defined _PAR_IO && defined _HDF5_IO
 integer, parameter:: PAR_IO_CREATE_MODE=ior(nf90_mpiio,nf90_netcdf4)
 integer, parameter:: PAR_IO_WRITE_MODE =ior(nf90_mpiio,nf90_write)
#endif
#if defined _PAR_IO && !defined _HDF5_IO
 integer, parameter:: PAR_IO_CREATE_MODE=ior(nf90_mpiio,nf90_64bit_offset)
 integer, parameter:: PAR_IO_WRITE_MODE =ior(nf90_mpiio,nf90_write)
#endif
 !
#if defined _DOUBLE
 complex(DP), parameter :: YAMBO_CMPLX_NO_FILL = cmplx(nf90_fill_double,nf90_fill_double)
#else
 complex(SP), parameter :: YAMBO_CMPLX_NO_FILL = cmplx(nf90_fill_real,  nf90_fill_real)
#endif
 !
 ! Netcdf chunking
 ! For SP, we chunk in 2MB and double 4MB. These are in general small chunk sizes. 
 ! For more information see https://www.unidata.ucar.edu/software/netcdf/workshops/2011/nc4chunking/
 integer, parameter :: YAMBO_DEF_CHUNK = 512
 !
 ! Units
 !
 integer :: io_action(max_io_units)
 integer :: io_com(max_io_units)
 integer :: io_mode(max_io_units)
 integer :: io_status(max_io_units)
 integer :: io_type(max_io_units)
 integer :: io_sec(max_io_units,max_active_sections)
 integer :: io_rec_pos(max_io_units)
 integer :: io_unit(max_io_units)
 integer :: io_restart_point(max_io_units)
 integer :: io_code_version(max_io_units,3)
 integer :: io_code_revision(max_io_units,2) ! devel,GPL
 integer :: io_serial_number(max_io_units)
 !
 ! io_netcdf_var(ID,1)  is used for tmp vars by io_elemental, io_bulk,  def/io_variable_elemental
 ! io_netcdf_var(ID,2:) is used for stored var-IDs by def/io_variable_bulk
 integer :: io_netcdf_var(max_io_units,max_io_vars_open) 
 logical :: io_resetable(max_io_units)
 character(lchlen)          :: io_file(max_io_units)
 character(lchlen)          :: io_folder(max_io_units)
 !
 ! Parallel I/O
 integer :: io_PAR_comm(max_io_units) ! COMM allowed to write the DB
 integer :: io_PAR_cpu(max_io_units)  ! =1 if the CPU is part of the COMM and/or allowed to read/write
                                      ! =0 otherwise
 !
 ! Type & extension
 !
 character(schlen)          :: io_raw_extension(max_io_units) ! Used to define the restart files.
                                                              ! It differs from io_extension as it does not contain any
                                                              ! i_fragment/j_fragment.
 character(schlen)          :: io_extension(max_io_units)
 !
 ! Save variables (to try different DB locations at the same time)
 !
 integer, private :: io_unit_save
 integer, private :: io_action_save
 integer, private :: io_mode_save
 integer, private :: io_sec_save(max_io_units)
 integer, private :: io_com_save
 !
 contains
   ! 
   logical function open_is_on(ID)
     !
     ! Note that an identical IF statement must be defined in io_control.
     !
     integer :: ID
     open_is_on=any((/io_action(ID)==OP_RD_CL,io_action(ID)==OP_WR_CL,&
&                     io_action(ID)==OP_APP_CL,io_action(ID)==OP_RD,&
&                     io_action(ID)==OP_APP,io_action(ID)==OP_WR/))
   end function
   !
   logical function close_is_on(ID)
     !
     integer :: ID
     close_is_on=any((/io_action(ID)==RD_CL,io_action(ID)==OP_RD_CL,&
&                      io_action(ID)==OP_WR_CL,io_action(ID)==OP_APP_CL,&
&                      io_action(ID)==WR_CL/))
   end function
   !
   logical function read_is_on(ID)
     !
     integer :: ID
     read_is_on=any((/io_action(ID)==OP_RD_CL,       io_action(ID)==OP_RD,&
&                     io_action(ID)==   RD_CL,       io_action(ID)==   RD,&
&                     io_action(ID)==   RD_CL_IF_END,io_action(ID)==OP_IF_START_RD_CL_IF_END/))
   end function
   !
   logical function write_is_on(ID)
     !
     integer :: ID
     write_is_on=any((/io_action(ID)==OP_WR_CL       ,io_action(ID)==OP_APP_CL,&
&                      io_action(ID)==   WR          ,io_action(ID)==OP_APP      ,&
&                      io_action(ID)==OP_WR          ,io_action(ID)==       WR_CL,&
&                                                     io_action(ID)==OP_IF_START_APP_CL_IF_END,&
&                      io_action(ID)==   WR_CL_IF_END,io_action(ID)==OP_IF_START_WR_CL_IF_END/))
   end function
   ! 
   logical function DB_is_OK(ID)
     !
     integer :: ID
     DB_is_OK=any((/io_status(ID)==IO_NO_ERROR,io_status(ID)==IO_NO_BINDING_ERROR/))
     !
   end function
   !
#if !defined _io_lib
   integer function manage_action(IO_ACTION,NOW,FIRST,LAST,PAR_index,element_1D)
     !
     use parallel_m, ONLY:PP_indexes
     !
     integer, intent(in) :: IO_ACTION,NOW
     integer, intent(in) :: FIRST,LAST
     type(PP_indexes), intent(in), optional :: PAR_index
     logical, intent(in),          optional :: element_1D(LAST-FIRST+1)
     !
     integer :: start_,end_,ii,N
     logical, allocatable :: element_1D_(:)
     !
     end_  =LAST
     start_=FIRST
     !
     if (present(PAR_index)) then
       if(.not.allocated(PAR_index%element_1D)) call error(" manage action, element_1S of PAR_index not allocated")
       N=size(PAR_index%element_1D)
       allocate(element_1D_(N))
       element_1D_=PAR_index%element_1D
     endif
     !
     if (present(element_1D)) then
       N=LAST-FIRST+1
       allocate(element_1D_(N))
       element_1D_=element_1D
     endif
     !
     if(allocated(element_1D_)) then
       start_=0
       end_  =0
       do ii=1,N
         if (element_1D_(ii)) then
           if (start_==0) start_=ii
           end_=ii
         endif
       enddo
     endif
     !
     manage_action=IO_ACTION
     !
     if (IO_ACTION== OP_IF_START_RD_CL_IF_END.and.NOW> start_.and.NOW< end_) manage_action=    RD
     if (IO_ACTION==             RD_CL_IF_END.and.                NOW< end_) manage_action=    RD
     if (IO_ACTION== OP_IF_START_RD_CL_IF_END.and.NOW==start_              ) manage_action= OP_RD
     if (IO_ACTION== OP_IF_START_RD_CL_IF_END.and.                NOW==end_) manage_action=    RD_CL
     if (IO_ACTION==             RD_CL_IF_END.and.                NOW==end_) manage_action=    RD_CL
     if (IO_ACTION== OP_IF_START_RD_CL_IF_END.and.NOW==start_.and.NOW==end_) manage_action= OP_RD_CL
     !
     if (IO_ACTION== OP_IF_START_WR_CL_IF_END.and.NOW> start_.and.NOW< end_) manage_action=    WR
     if (IO_ACTION==             WR_CL_IF_END.and.                NOW< end_) manage_action=    WR
     if (IO_ACTION== OP_IF_START_WR_CL_IF_END.and.NOW==start_              ) manage_action= OP_WR
     if (IO_ACTION== OP_IF_START_WR_CL_IF_END.and.                NOW==end_) manage_action=    WR_CL
     if (IO_ACTION==             WR_CL_IF_END.and.                NOW==end_) manage_action=    WR_CL
     if (IO_ACTION== OP_IF_START_WR_CL_IF_END.and.NOW==start_.and.NOW==end_) manage_action= OP_WR_CL
     !
     if (IO_ACTION==OP_IF_START_APP_CL_IF_END.and.NOW> start_.and.NOW< end_) manage_action=    WR
     if (IO_ACTION==OP_IF_START_APP_CL_IF_END.and.NOW==start_              ) manage_action=OP_APP
     if (IO_ACTION==OP_IF_START_APP_CL_IF_END.and.                NOW==end_) manage_action=    WR_CL
     if (IO_ACTION==OP_IF_START_APP_CL_IF_END.and.NOW==start_.and.NOW==end_) manage_action=OP_APP_CL
     !
   end function manage_action
#endif
   !
   subroutine io_reset(ID)
     use parallel_m, ONLY:mpi_comm_null
     integer :: ID
     io_status(ID)=0
     !
     io_PAR_comm(ID)=mpi_comm_null
     io_PAR_cpu(ID)=0
     io_unit(ID)=0
     io_mode(ID)=0
     io_sec(ID,:)=0
     io_com(ID)=NONE
     io_file(ID)=' ' 
     io_folder(ID)=' ' 
     io_raw_extension(ID)=' ' 
     io_extension(ID)=' ' 
     io_rec_pos(ID)=1
     io_restart_point(ID)=1
#if !defined _io_lib
     io_code_version(ID,:)=code_version
     io_code_revision(ID,:)=(/code_revision,code_GPL_revision/)
#endif
     io_serial_number(ID)=serial_number
     io_resetable(ID)=.true.
   end subroutine
   !
   subroutine mk_dir(dirname)
     use pars,           ONLY:schlen
     use stderr,         ONLY:cstr,STRING_split
     implicit none
     character(*)      :: dirname
     integer           :: i_j,n_s
     character(schlen) :: dir(10)
     character(lchlen) :: ch_tmp
     if (len_trim(dirname)==0) return
     call STRING_split(trim(dirname),dir,"/",n_non_empty_strings=n_s)
     ch_tmp=dir(1)
     if(dirname(1:1)=="/") ch_tmp="/"//trim(ch_tmp)
     call imkdir( cstr(trim(ch_tmp)) )
     do i_j=2,n_s
       ch_tmp=trim(ch_tmp)//"/"//trim(dir(i_j))
       call imkdir( cstr(trim(ch_tmp)) )
     enddo
   end subroutine
   !
   character(lchlen) function DB_path(dir_,job_,db_)
     implicit none
     character(*)      :: dir_,job_,db_
     DB_path=" "
     if (len_trim(dir_)>0) DB_path=trim(dir_)//"/"
     if (len_trim(job_)>0) DB_path=trim(DB_path)//trim(job_)//"/"
     DB_path=trim(DB_path)//trim(db_)
   end function
   !
   subroutine cp_file(file_,dest_,ierr_)
     use stderr,         ONLY:cstr
     implicit none
     character(*)      :: file_,dest_
     integer           :: ierr_
     call isystem( cstr("bash -c 'cp "//file_//" "//dest_//" >& /dev/null' " ), ierr_ )
   end subroutine
   !
   subroutine cp_directory(dir_,dest_,ierr_)
     use stderr,         ONLY:cstr
     implicit none
     character(*)      :: dir_,dest_
     integer           :: ierr_
     call isystem( cstr("bash -c 'cp -R "//dir_//" "//dest_//" >& /dev/null' " ), ierr_ )
   end subroutine
   !
   subroutine rm_file(filename)
     use stderr,         ONLY:cstr
     implicit none
     character(*)      :: filename
     if (len_trim(filename)==0) return
     call iremove( cstr(trim(filename)) )
   end subroutine
   !
   subroutine rename_file(filename_old,filename_new)
     use stderr,    ONLY:cstr
     implicit none
     character(*)      :: filename_old,filename_new
     if (len_trim(filename_old)==0) return
     call irename( cstr(trim(filename_old)), cstr(trim(filename_new)) )
   end subroutine
   !
   logical function file_is_present(desc,subfolder)
     !
     use pars,         ONLY:num_of_alternative_locations
     use IO_int,       ONLY:all_locations
     !
     character(*)           :: desc
     character(*), optional :: subfolder
     !
     ! Work Space
     !
     integer            :: i_f
     character(lchlen)  :: possible_locations(num_of_alternative_locations)
     character(schlen)  :: subfolder_
     !
     logical, external :: file_exists
     !
     subfolder_=' '
     if (present(subfolder)) subfolder_=subfolder
     !
     possible_locations=all_locations(desc,subfolder_)
     !
     file_is_present=.true.
     do i_f=1,num_of_alternative_locations
       if( file_exists(trim( possible_locations(i_f) )  ) ) return
     enddo
     file_is_present=.false.
     !
   end function file_is_present
   !
   logical function NETCDF_file_is_open(ID)
     integer, optional :: ID
     integer :: NC_ERR
     NETCDF_file_is_open=.false.
     if (trim(IO_file(ID))=='') return
     NC_ERR=nf90_inquire(io_unit(ID))
     NETCDF_file_is_open=NC_ERR==NF90_NOERR
   end function
   !
   logical function PLAIN_file_is_open(filename)
     character(*) :: filename
     PLAIN_file_is_open=.FALSE.
     if (trim(filename)=='') return
     INQUIRE (FILE=trim(filename),OPENED=PLAIN_file_is_open)
   end function
   !
   subroutine netcdf_call(status,ID,VAR,ID_VAR)
     integer,      intent (in)           :: status
     integer,      intent (in)           :: ID
     integer,      intent (in), optional :: ID_VAR
     character(*), intent (in), optional :: VAR
     character(lchlen) :: msg
     character(schlen) :: VARNAME,FILENAME
     integer           :: local_error,VARNUMBER
     if(status /= NF90_NOERR) then
       FILENAME=io_file(ID)
       VARNAME=' NOT DEFINED '
       if(.not.present(VAR)) then
         if(     present(ID_VAR)) VARNUMBER=io_netcdf_var(ID,ID_VAR)
         if(.not.present(ID_VAR)) VARNUMBER=io_netcdf_var(ID,1)
         local_error=nf90_inquire_variable(io_unit(ID),VARNUMBER,VARNAME)
         if(local_error/=0) VARNAME=' NOT DEFINED '
       endif
       if(present(VAR)) VARNAME=VAR
       if( read_is_on(ID)) write (msg,'(6a)') ' Reading File ',trim(FILENAME),'; Variable ',&
&                                             trim(VARNAME),'; ',trim(nf90_strerror(status))
       if (write_is_on(ID)) write (msg,'(6a)') ' Writing File ',trim(FILENAME),'; Variable ',&
&                                             trim(VARNAME),'; ',trim(nf90_strerror(status))
       call error(trim(msg))
     end if
   end subroutine
   !
   integer function netcdf_dim_size(ID,DIMNAME)
     ! Returns the value of the specified dim of a variable
     integer,      intent(in)    :: ID
     character(*), intent(inout) :: DIMNAME
     integer                     :: nf90_err,NF90_DIM_ID
     netcdf_dim_size=0
     nf90_err=nf90_inq_dimid(io_unit(ID),DIMNAME,NF90_DIM_ID)
     if(nf90_err/=NF90_NOERR) return
     nf90_err=nf90_inquire_dimension(io_unit(ID),NF90_DIM_ID, name = dimname, len = netcdf_dim_size)
   end function
   !
   integer function netcdf_dim(ID,DIM,dim_name)
     ! Returns the ID of the netcdf dimension
     integer,intent(in)         :: ID,DIM
     character(schlen),optional :: dim_name
     !
     integer                    :: nf90_err
     character(schlen)          :: dim_strng
     netcdf_dim=0
     if (.not.present(dim_name)) write (dim_strng,'(a,i10.10)') 'D_',dim
     if (     present(dim_name)) dim_strng = dim_name
     nf90_err=nf90_inq_dimid(io_unit(ID),dim_strng,netcdf_dim)
     if (nf90_err/=NF90_NOERR) call netcdf_call(nf90_def_dim(io_unit(ID),dim_strng,dim,netcdf_dim),ID)
   end function
   !
   logical function variable_exist(ID,var_name,var_ID)
     integer,           intent ( in) :: ID
     character(*),      intent ( in) :: var_name
     integer, optional, intent (out) :: var_ID
     integer                    :: var_check,var_ID_
     var_check=nf90_inq_varid(io_unit(ID),var_name,var_ID_)
     if (var_check==NF90_NOERR) variable_exist=.TRUE.
     if (var_check/=NF90_NOERR) variable_exist=.FALSE.
     if (present(var_ID)) then
       if(     variable_exist) var_ID=var_ID_
       if(.not.variable_exist) var_ID=-1
     endif
   end function
   !
   subroutine deliver_IO_error_message(i_err,DB,STOP_it)
     !
     integer          :: i_err
     logical,optional :: STOP_it
     character(*)     :: DB
     !
     ! ws
     logical          :: STOP_
     !
     if (i_err==0) return
     !
     STOP_=.FALSE.
     if (present(STOP_it)) STOP_=STOP_it
     !
     if (STOP_) then
       if (i_err==IO_NO_DATABASE     ) call error('Missing all or part of '//DB//' DB')
       if (i_err==IO_INCOMPATIBLE_VAR) call error('Variable not compatible in '//DB//' DB')
       if (i_err==IO_OUTDATED_DB)      call error('Too old '//DB//' DB')
     else
       if (i_err==IO_NO_DATABASE     ) call warning('Missing all or part of '//DB//' DB')
       if (i_err==IO_INCOMPATIBLE_VAR) call warning('Variable not compatible in '//DB//' DB')
       if (i_err==IO_OUTDATED_DB)      call warning('Too old '//DB//' DB')
     endif
     !
   end subroutine
   !
end module IO_m
