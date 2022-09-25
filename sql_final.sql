-- Итоговая работа по модулю
-- “SQL и получение данных”

-- Приложение №2

-- 1. В каких городах больше одного аэропорта?

select city "Города", count(airport_code) "Количество аэропортов" -- выводим города и количество аэропортов в них
from airports  -- получили данные по аэропортам
group by city  -- группируем по городам
having count(airport_code) > 1 -- после группировки находим города, где количество аэропортов больше 1


-- 2. В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета?

select a.airport_name "Аэропорты"  -- вывели названия аэропортов
from airports a  -- объединили таблицы с аэропортами, полетами и самолетами с максимальной дальностью перелета
	join flights f on a.airport_code = f.departure_airport 
	join aircrafts a2 on f.aircraft_code = a2.aircraft_code 
	join (select max(range) max_r  -- нашли максимальную дальность полета 
			from aircrafts) t on a2."range" = t.max_r 
group by a.airport_code  -- сгруппировали по кодам аэропортов
order by a.airport_name  -- отсортировали по названиям аэропортов


-- 3. Вывести 10 рейсов с максимальным временем задержки вылета

select flight_id "ID рейса", (f.actual_departure - f.scheduled_departure) as "Задержка вылета" -- вывели рейсы и их время задержки вылета
from flights f  -- получили данные по полетам
where (f.actual_departure - f.scheduled_departure) is not null -- оставили рейсы, где была задержка вылета
order by "Задержка вылета" desc  -- отсортировали рейсы по задержке вылета от большего к меньшему
limit 10  -- оставили первые 10 рейсов


-- 4. Были ли брони, по которым не были получены посадочные талоны?

select distinct t.book_ref "Брони без посадочных талонов" -- вывели уникальные значения номеров бронирования
	from tickets t 
	left join boarding_passes bp on t.ticket_no = bp.ticket_no 
where bp.boarding_no is null -- оставили данные, где номер посадочного талона имеет значение null
	

-- 5. Найдите количество свободных мест для каждого рейса, их % отношение к общему количеству мест в самолете.
   -- Добавьте столбец с накопительным итогом - суммарное накопление количества вывезенных пассажиров из каждого аэропорта на каждый день. 
   -- Т.е. в этом столбце должна отражаться накопительная сумма - сколько человек уже вылетело из данного аэропорта на этом или более ранних 
   -- рейсах в течении дня.

with cte_1 as ( -- создали cte с объединенными и сгруппированными данными из таблиц рейсы, самолеты, места в самолетах и аэропорты
	select f.flight_id, f.departure_airport, ap.airport_name, f.actual_departure, a.aircraft_code, a.model, 
		count(s.seat_no) seats -- посчитали общее количество мест в самолете
	from flights f 
	join aircrafts a on f.aircraft_code = a.aircraft_code 
	join seats s on a.aircraft_code = s.aircraft_code 
	join airports ap on f.departure_airport = ap.airport_code 
	group by 1, 2, 3, 4, 5 ),
cte_2 as ( -- создали cte с объединенными и сгруппированными данными из таблиц ticket_flights и посадочные талоны
	select tf.flight_id, count(bp.seat_no) b_seats -- выбрали id рейсов и посчитали количество занятых мест по каждому рейсу
	from ticket_flights tf 
	join boarding_passes bp on tf.ticket_no = bp.ticket_no and tf.flight_id = bp.flight_id 
	group by 1 )
select cte_1.airport_name "Аэропорт", cte_1.flight_id "Рейс", cte_1.model "Модель самолета", cte_1.actual_departure "Дата и время вылета", 
	cte_2.b_seats "Количество пассажиров", 
	sum(cte_2.b_seats) -- посчитали суммарное накопление пассажиров с помощью оконной функции
	over (partition by cte_1.departure_airport, cte_1.actual_departure::date order by cte_1.actual_departure) "Суммарное накопление пассажиров",
	(cte_1.seats - cte_2.b_seats) "Свободные места", -- посчитали количество свободных мест в рейсах
	((cte_1.seats - cte_2.b_seats)*100/cte_1.seats) "% св.мест от общего кол-ва мест" -- нашли % свободных мест от общего количества мест в самолете
from cte_1 -- объединили данные из двух cte
	join cte_2 on cte_2.flight_id = cte_1.flight_id
	

-- 6. Найдите процентное соотношение перелетов по типам самолетов от общего количества.

select a.model "Модель самолета", t.count_a "Количество перелетов", 
	round((count_a * 100)/all_flights::numeric, 2) "% от общего кол-ва перелетов" -- рассчитали % перелетов от общего числа рейсов, округлив до 2 знаков после запятой
from (
	select f.flight_id, f.aircraft_code,
		count(f.flight_id) over (partition by f.aircraft_code) count_a, -- посчитали количество рейсов для каждого самолета
		count(f.flight_id) over () all_flights -- посчитали общее количество рейсов (все рейсы)
		from flights f ) t
join aircrafts a on t.aircraft_code = a.aircraft_code -- полученные в подзапросе данные из таблицы рейсы объединили с таблицей самолеты
group by 1, 2, 3 -- сгруппировали данные по модели самолетов, числу перелетов и % перелетов


-- 7. Были ли города, в которые можно  добраться бизнес - классом дешевле, чем эконом-классом в рамках перелета?

with cte_1 as ( -- создали cte с данными по всем рейсам с местами эконом-класса и их стоимостью
	select f.flight_id, tf.fare_conditions, tf.amount, a.city
		from flights f 
		join ticket_flights tf on f.flight_id = tf.flight_id 
		join airports a on f.arrival_airport  = a.airport_code 
	where tf.fare_conditions = 'Economy'
	group by 1, 2, 3, 4
	order by 1, 2 ),
cte_2 as ( -- создали cte с данными по всем рейсам с местами бизнес-класса и их стоимостью
	select f.flight_id, tf.fare_conditions, tf.amount, a.city
		from flights f 
		join ticket_flights tf on f.flight_id = tf.flight_id 
		join airports a on f.arrival_airport  = a.airport_code 
	where tf.fare_conditions = 'Business'
	group by 1, 2, 3, 4
	order by 1, 2 )
select cte_2.city "Город прибытия", cte_1.flight_id "Рейс", cte_1.amount "Цена эконом-класса", cte_2.amount "Цена бизнес-класса"
from cte_1 
	join cte_2 on cte_1.flight_id = cte_2.flight_id -- объединили cte_1 и cte_2
where cte_2.amount < cte_1.amount -- с условием, что стоимость бизнес-класса меньше стоимости эконом-класса


-- 8. Между какими городами нет прямых рейсов?

create view flights_cities as  -- создали представление, которое находит по всем рейсам город отправления самолета и город прибытия самолета
select a.city "Город отправления", a1.city "Город прибытия" 
	from flights f
	join airports a on f.departure_airport = a.airport_code
	join airports a1 on f.arrival_airport = a1.airport_code 
	group by 1, 2 -- сгруппировали данные по городам, чтобы убрать повторы

select a.city "Город отправления", a1.city "Город прибытия"
	from airports a, airports a1 -- из городов таблицы аэропорты сдалали декартово произведение
	where a.city != a1.city -- условие, что город вылета не равен городу прилета
except -- из всех вариантов перелетов между городами исключили (вычли) существующие перелеты
select "Город отправления", "Город прибытия"
	from flights_cities
order by 1  -- отсортировали по алфавиту города отправления для удобства восприятия


-- 9. Вычислите расстояние между аэропортами, связанными прямыми рейсами, 
   -- сравните с допустимой максимальной дальностью перелетов  в самолетах, обслуживающих эти рейсы

select model "Модель самолета", range "Max дальность полета", name1 "Отправление", name2 "Прибытие", L "Дальность полета (км)",
	case 
		when "range" > L then 'Долетит' -- если максимальная дальность полета самолета больше дальности его перелета в рейсе, то самолет долетит
		else 'Не долетит'  -- в остальных случаях - не долетит 
	end "Долетит/Не долетит"
from (  
	select a.model, a.range, name1, name2, 
			round(((acos(sind(lat1) * sind(lat2) + cosd(lat1) * cosd(lat2) * cosd(lon1 - lon2))) * 6371)::numeric, 3) as L -- рассчитали расстояние между аэропортом вылета и аэропортом прилета по каждому рейсу и округлили до тясячных (до метров)
		from (  
			select f.aircraft_code, f.departure_airport, a1.airport_name name1, 
					a1.longitude::double precision lon1, a1.latitude::double precision lat1, 
					f.arrival_airport, a2.airport_name name2, a2.longitude::double precision lon2, 
					a2.latitude::double precision lat2 -- все данные по широте и долготе преобразовали в тип double precision
				from flights f -- обогатили таблицу рейсы данными из таблицы аэропорты, чтобы получить названия аэропортов
				join airports a1 on f.departure_airport = a1.airport_code 
				join airports a2 on f.arrival_airport = a2.airport_code
			group by 1, 2, 3, 4, 5, 6, 7, 8, 9 ) t  -- сгруппировали данные
		join aircrafts a on t.aircraft_code = a.aircraft_code -- объединили обогащенную таблицу рейсы с таблицей самолеты
	order by 1) t1







































