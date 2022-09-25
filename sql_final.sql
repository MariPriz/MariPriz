-- �������� ������ �� ������
-- �SQL � ��������� �������

-- ���������� �2

-- 1. � ����� ������� ������ ������ ���������?

select city "������", count(airport_code) "���������� ����������" -- ������� ������ � ���������� ���������� � ���
from airports  -- �������� ������ �� ����������
group by city  -- ���������� �� �������
having count(airport_code) > 1 -- ����� ����������� ������� ������, ��� ���������� ���������� ������ 1


-- 2. � ����� ���������� ���� �����, ����������� ��������� � ������������ ���������� ��������?

select a.airport_name "���������"  -- ������ �������� ����������
from airports a  -- ���������� ������� � �����������, �������� � ���������� � ������������ ���������� ��������
	join flights f on a.airport_code = f.departure_airport 
	join aircrafts a2 on f.aircraft_code = a2.aircraft_code 
	join (select max(range) max_r  -- ����� ������������ ��������� ������ 
			from aircrafts) t on a2."range" = t.max_r 
group by a.airport_code  -- ������������� �� ����� ����������
order by a.airport_name  -- ������������� �� ��������� ����������


-- 3. ������� 10 ������ � ������������ �������� �������� ������

select flight_id "ID �����", (f.actual_departure - f.scheduled_departure) as "�������� ������" -- ������ ����� � �� ����� �������� ������
from flights f  -- �������� ������ �� �������
where (f.actual_departure - f.scheduled_departure) is not null -- �������� �����, ��� ���� �������� ������
order by "�������� ������" desc  -- ������������� ����� �� �������� ������ �� �������� � ��������
limit 10  -- �������� ������ 10 ������


-- 4. ���� �� �����, �� ������� �� ���� �������� ���������� ������?

select distinct t.book_ref "����� ��� ���������� �������" -- ������ ���������� �������� ������� ������������
	from tickets t 
	left join boarding_passes bp on t.ticket_no = bp.ticket_no 
where bp.boarding_no is null -- �������� ������, ��� ����� ����������� ������ ����� �������� null
	

-- 5. ������� ���������� ��������� ���� ��� ������� �����, �� % ��������� � ������ ���������� ���� � ��������.
   -- �������� ������� � ������������� ������ - ��������� ���������� ���������� ���������� ���������� �� ������� ��������� �� ������ ����. 
   -- �.�. � ���� ������� ������ ���������� ������������� ����� - ������� ������� ��� �������� �� ������� ��������� �� ���� ��� ����� ������ 
   -- ������ � ������� ���.

with cte_1 as ( -- ������� cte � ������������� � ���������������� ������� �� ������ �����, ��������, ����� � ��������� � ���������
	select f.flight_id, f.departure_airport, ap.airport_name, f.actual_departure, a.aircraft_code, a.model, 
		count(s.seat_no) seats -- ��������� ����� ���������� ���� � ��������
	from flights f 
	join aircrafts a on f.aircraft_code = a.aircraft_code 
	join seats s on a.aircraft_code = s.aircraft_code 
	join airports ap on f.departure_airport = ap.airport_code 
	group by 1, 2, 3, 4, 5 ),
cte_2 as ( -- ������� cte � ������������� � ���������������� ������� �� ������ ticket_flights � ���������� ������
	select tf.flight_id, count(bp.seat_no) b_seats -- ������� id ������ � ��������� ���������� ������� ���� �� ������� �����
	from ticket_flights tf 
	join boarding_passes bp on tf.ticket_no = bp.ticket_no and tf.flight_id = bp.flight_id 
	group by 1 )
select cte_1.airport_name "��������", cte_1.flight_id "����", cte_1.model "������ ��������", cte_1.actual_departure "���� � ����� ������", 
	cte_2.b_seats "���������� ����������", 
	sum(cte_2.b_seats) -- ��������� ��������� ���������� ���������� � ������� ������� �������
	over (partition by cte_1.departure_airport, cte_1.actual_departure::date order by cte_1.actual_departure) "��������� ���������� ����������",
	(cte_1.seats - cte_2.b_seats) "��������� �����", -- ��������� ���������� ��������� ���� � ������
	((cte_1.seats - cte_2.b_seats)*100/cte_1.seats) "% ��.���� �� ������ ���-�� ����" -- ����� % ��������� ���� �� ������ ���������� ���� � ��������
from cte_1 -- ���������� ������ �� ���� cte
	join cte_2 on cte_2.flight_id = cte_1.flight_id
	

-- 6. ������� ���������� ����������� ��������� �� ����� ��������� �� ������ ����������.

select a.model "������ ��������", t.count_a "���������� ���������", 
	round((count_a * 100)/all_flights::numeric, 2) "% �� ������ ���-�� ���������" -- ���������� % ��������� �� ������ ����� ������, �������� �� 2 ������ ����� �������
from (
	select f.flight_id, f.aircraft_code,
		count(f.flight_id) over (partition by f.aircraft_code) count_a, -- ��������� ���������� ������ ��� ������� ��������
		count(f.flight_id) over () all_flights -- ��������� ����� ���������� ������ (��� �����)
		from flights f ) t
join aircrafts a on t.aircraft_code = a.aircraft_code -- ���������� � ���������� ������ �� ������� ����� ���������� � �������� ��������
group by 1, 2, 3 -- ������������� ������ �� ������ ���������, ����� ��������� � % ���������


-- 7. ���� �� ������, � ������� �����  ��������� ������ - ������� �������, ��� ������-������� � ������ ��������?

with cte_1 as ( -- ������� cte � ������� �� ���� ������ � ������� ������-������ � �� ����������
	select f.flight_id, tf.fare_conditions, tf.amount, a.city
		from flights f 
		join ticket_flights tf on f.flight_id = tf.flight_id 
		join airports a on f.arrival_airport  = a.airport_code 
	where tf.fare_conditions = 'Economy'
	group by 1, 2, 3, 4
	order by 1, 2 ),
cte_2 as ( -- ������� cte � ������� �� ���� ������ � ������� ������-������ � �� ����������
	select f.flight_id, tf.fare_conditions, tf.amount, a.city
		from flights f 
		join ticket_flights tf on f.flight_id = tf.flight_id 
		join airports a on f.arrival_airport  = a.airport_code 
	where tf.fare_conditions = 'Business'
	group by 1, 2, 3, 4
	order by 1, 2 )
select cte_2.city "����� ��������", cte_1.flight_id "����", cte_1.amount "���� ������-������", cte_2.amount "���� ������-������"
from cte_1 
	join cte_2 on cte_1.flight_id = cte_2.flight_id -- ���������� cte_1 � cte_2
where cte_2.amount < cte_1.amount -- � ��������, ��� ��������� ������-������ ������ ��������� ������-������


-- 8. ����� ������ �������� ��� ������ ������?

create view flights_cities as  -- ������� �������������, ������� ������� �� ���� ������ ����� ����������� �������� � ����� �������� ��������
select a.city "����� �����������", a1.city "����� ��������" 
	from flights f
	join airports a on f.departure_airport = a.airport_code
	join airports a1 on f.arrival_airport = a1.airport_code 
	group by 1, 2 -- ������������� ������ �� �������, ����� ������ �������

select a.city "����� �����������", a1.city "����� ��������"
	from airports a, airports a1 -- �� ������� ������� ��������� ������� ��������� ������������
	where a.city != a1.city -- �������, ��� ����� ������ �� ����� ������ �������
except -- �� ���� ��������� ��������� ����� �������� ��������� (�����) ������������ ��������
select "����� �����������", "����� ��������"
	from flights_cities
order by 1  -- ������������� �� �������� ������ ����������� ��� �������� ����������


-- 9. ��������� ���������� ����� �����������, ���������� ������� �������, 
   -- �������� � ���������� ������������ ���������� ���������  � ���������, ������������� ��� �����

select model "������ ��������", range "Max ��������� ������", name1 "�����������", name2 "��������", L "��������� ������ (��)",
	case 
		when "range" > L then '�������' -- ���� ������������ ��������� ������ �������� ������ ��������� ��� �������� � �����, �� ������� �������
		else '�� �������'  -- � ��������� ������� - �� ������� 
	end "�������/�� �������"
from (  
	select a.model, a.range, name1, name2, 
			round(((acos(sind(lat1) * sind(lat2) + cosd(lat1) * cosd(lat2) * cosd(lon1 - lon2))) * 6371)::numeric, 3) as L -- ���������� ���������� ����� ���������� ������ � ���������� ������� �� ������� ����� � ��������� �� �������� (�� ������)
		from (  
			select f.aircraft_code, f.departure_airport, a1.airport_name name1, 
					a1.longitude::double precision lon1, a1.latitude::double precision lat1, 
					f.arrival_airport, a2.airport_name name2, a2.longitude::double precision lon2, 
					a2.latitude::double precision lat2 -- ��� ������ �� ������ � ������� ������������� � ��� double precision
				from flights f -- ��������� ������� ����� ������� �� ������� ���������, ����� �������� �������� ����������
				join airports a1 on f.departure_airport = a1.airport_code 
				join airports a2 on f.arrival_airport = a2.airport_code
			group by 1, 2, 3, 4, 5, 6, 7, 8, 9 ) t  -- ������������� ������
		join aircrafts a on t.aircraft_code = a.aircraft_code -- ���������� ����������� ������� ����� � �������� ��������
	order by 1) t1







































