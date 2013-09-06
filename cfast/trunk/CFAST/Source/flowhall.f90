
! --------------------------- hallht -------------------------------------------

    subroutine hallht(iroom,idstart,nd)

    !     routine: hallht
    !     purpose: this routine computes the velocity and temperature
    !               of the ceiling jet at each detector location in
    !               a corridor.
    !     arguments: iroom - room number of corridor
    !                idstart - index of first detector in corridor iroom
    !                nd - number of detectors in room iroom

    use precision_parameters
    use cenviro
    use cfast_main
    implicit none

    integer, intent(in) :: iroom, idstart, nd    

    real(eb) :: xx, yy, zz, xlen, temp, rho, vel
    integer :: id
    
    type(room_type), pointer :: roomi

    roomi=>roominfo(iroom)
    
    do id = idstart, idstart + nd - 1
        xx = xdtect(id,dxloc)
        yy = xdtect(id,dyloc)
        zz = xdtect(id,dzloc)
        if(roomi%izhall(ihxy)==1)then
            xlen = xx
        else
            xlen = yy
        endif
        call halltrv(iroom,xlen,zz,temp,rho,vel)
        xdtect(id,dtjet) = temp
        xdtect(id,dvel) = vel
    end do
    return
    end

! --------------------------- halltrv -------------------------------------------

    subroutine halltrv (iroom,xloc,zloc,halltemp,hallrho,hallvel)

    use precision_parameters
    use cenviro
    use cfast_main
    implicit none
    
    real(eb), intent(in) :: xloc, zloc
    real(eb), intent(out) ::  halltemp, hallrho, hallvel
    integer, intent(in) :: iroom
    
    real(eb) :: cjetheight, c1, hhalf, dt0, fact
    integer :: ihalf
    type(room_type), pointer :: roomi

    roomi=>roominfo(iroom)
    
    if(roomi%izhall(ihmode)==ihduring)then
        cjetheight = roomi%hr - roomi%zzhall(ihdepth)

        ! location is in hall ceiling jet
        if(zloc>=cjetheight.and.xloc<=roomi%zzhall(ihdist))then
            c1 = 1.0_eb
            ihalf = roomi%izhall(ihhalfflag)
            hhalf = roomi%zzhall(ihhalf)
            dt0 = roomi%zzhall(ihtemp)

            ! check to see if the user specified a hhalf value on the command line. if not (ie if ihalf==0) then calculate it using the correlations.
            if(ihalf==0)then
                ! hhalf = -log10(2)/.018
                hhalf = 16.70_eb
                roomi%zzhall(ihhalf) = hhalf
            endif

            ! if hhalf < 0.0 then assume that the temperature does not decay (ie flow is adiabatic)
            if(hhalf>0.0_eb)then
                fact = 0.5_eb**(xloc/hhalf)
            else
                fact = 1.0_eb
            endif

            halltemp = roomi%zztemp(lower) + dt0*fact
            hallrho = roomi%zzpabs/(rgas*halltemp)
            hallvel = roomi%zzhall(ihvel)
        else
            halltemp = roomi%zztemp(lower)
            hallrho = roomi%zzrho(lower)
            hallvel = 0.10_eb
        endif
    else

        ! hall jet is not flowing (either has not started or has finished) so, use regular layer temperatures and densities
        if(zloc>roomi%zzhlay(lower))then
            halltemp = roomi%zztemp(upper)
            hallrho = roomi%zzrho(upper)
        else
            halltemp = roomi%zztemp(lower)
            hallrho = roomi%zzrho(lower)
        endif
        hallvel = 0.10_eb
    endif

    return
    end subroutine halltrv

! --------------------------- sethall -------------------------------------------

    subroutine sethall(itype, inum, ihall, tsec, width, htemp, hvel, hdepth)

    use precision_parameters
    use cenviro
    use cfast_main
    use dervs
    use vents
    implicit none

    real(eb), intent(in) :: tsec, width, htemp, hvel, hdepth
    
    real(eb) :: hhtemp, roomwidth, roomlength, ventwidth, fraction, halldepth, hallvel, ventdist, ventdist0, ventdistmin, ventdistmax, thall0, f1, f2, cjetdist
    integer :: ihall, inum, i, itype
    type(vent_type), pointer :: ventptr
    type(room_type), pointer :: hallroom
    
    ventptr=>ventinfo(inum)
    hallroom=>roominfo(ihall)
    
    hhtemp = htemp - hallroom%zztemp(lower)

    ! this routine is only executed if 1) hall flow has not started yet or 2)  hall flow has started and it is coming from the ivent'th vent

    if(hallroom%izhall(ihventnum)/=0.and.hallroom%izhall(ihventnum)/=inum)return
    roomwidth = min(hallroom%br,hallroom%dr)
    roomlength = max(hallroom%br,hallroom%dr)
    ventwidth = min(width,roomwidth)
    fraction = (ventwidth/roomwidth)**third
    halldepth = hdepth*fraction**2
    hallvel = hvel*fraction

    ! hall flow has not started yet
    if(hallroom%izhall(ihventnum)==0)then

        ! flow is going into the hall room and flow is below the soffit
        if(hallvel>0.0_eb.and.halldepth>0.0_eb)then
            hallroom%izhall(ihventnum) = inum
            hallroom%izhall(ihmode) = ihduring
            hallroom%zzhall(ihtime0) = tsec
            hallroom%zzhall(ihtemp) = hhtemp
            hallroom%zzhall(ihdist) = 0.0_eb
            if(hallroom%izhall(ihvelflag)==0)hallroom%zzhall(ihvel) = hallvel
            if(hallroom%izhall(ihdepthflag)==0)then
                hallroom%zzhall(ihdepth) = halldepth
            endif
            ventdist0 = -1.

            ! corridor flow coming from a vent 

            if(itype==1)then
                if(ventptr%from==ihall)then
                    ventdist0 = ventptr%from_hall_offset
                elseif(ventptr%to==ihall)then
                    ventdist0 = ventptr%to_hall_offset
                endif
            endif

            ! corridor flow coming from the main fire. this is a restriction, but lets get it right for the main fire before we worry about objects
            if(itype==2)then
                if(hallroom%izhall(ihxy)==1)then
                    ventdist0 = xfire(1,1)
                else
                    ventdist0 = xfire(1,2)
                endif
            endif
            hallroom%zzhall(ihorg) = ventdist0

            ventdist = -1.0_eb
            ventdistmax = ventdist 

            ! compute distances relative to vent where flow is coming from. also compute the maximum distance
            do i = 1, nvents
                ventptr=>ventinfo(i)
                if(ventptr%from==ihall)then

                    ! if distances are not defined for the origin or destination vent then assume that the vent at the "far" end of the corridor
                    if(ventptr%from_hall_offset>0.0_eb.and.ventdist0>=0.0_eb)then
                        ventdist = abs(ventptr%from_hall_offset - ventdist0)
                    else
                        ventdist = roomlength - ventdist0
                    endif
                    zzventdist(ihall,i) = ventdist
                elseif(ventptr%to==ihall)then

                    ! if distances are not defined for the origin or destination vent then assume that the vent at the "far" end of the corridor
                    if(ventptr%to_hall_offset>0.0_eb.and.ventdist0>=0.0_eb)then
                        ventdist = abs(ventptr%to_hall_offset - ventdist0)
                    else
                        ventdist = roomlength - ventdist0
                    endif
                    zzventdist(ihall,i) = ventdist
                else
                    ventdist = -1.0_eb
                    zzventdist(ihall,i) = ventdist
                endif
            end do

            ! let the maximum distance that flow in a corridor can flow be the width of the room, ie:
            hallroom%zzhall(ihmaxlen) = roomlength - ventdist0

            return
        endif
        return
    endif

    ! hall flow is coming from a vent or a fire
    if(hallroom%izhall(ihventnum)==inum)then
        thall0 = hallroom%zzhall(ihtime0)
        f1 = (told - thall0)/(stime-thall0)
        f2 = (stime - told)/(stime-thall0)
        if(hallroom%izhall(ihvelflag)==0)then
            hallroom%zzhall(ihvel) = hallroom%zzhall(ihvel)*f1 + abs(hallvel)*f2
        endif
        if(hallroom%izhall(ihdepthflag)==0)then
            hallroom%zzhall(ihdepth) = hallroom%zzhall(ihdepth)*f1 + halldepth*f2
        endif
        hallroom%zzhall(ihtemp) = hallroom%zzhall(ihtemp)*f1 + hhtemp*f2
        ventdistmax = hallroom%zzhall(ihmaxlen)
        ventdistmin = roomlength - ventdistmax
        cjetdist = hallroom%zzhall(ihdist) + dt*hallroom%zzhall(ihvel)

        ! if ceiling jet has reached the end of the hall then indicate this fact in izhall  
        if(cjetdist>=ventdistmax)then
            hallroom%izhall(ihmode) = ihafter
            cjetdist = ventdistmax
        endif
        hallroom%zzhall(ihdist) = cjetdist
    endif
    return
    end

! --------------------------- rev_flowhall -------------------------------------------

    integer function rev_flowhall ()

    INTEGER :: MODULE_REV
    CHARACTER(255) :: MODULE_DATE 
    CHARACTER(255), PARAMETER :: mainrev='$Revision$'
    CHARACTER(255), PARAMETER :: maindate='$Date$'

    WRITE(module_date,'(A)') mainrev(INDEX(mainrev,':')+1:LEN_TRIM(mainrev)-2)
    READ (MODULE_DATE,'(I5)') MODULE_REV
    rev_flowhall = module_rev
    WRITE(MODULE_DATE,'(A)') maindate
    return
    end function rev_flowhall