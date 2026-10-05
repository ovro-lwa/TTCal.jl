@testset "rungekutta.jl" begin
    f(x) = x
    rk2 = TTCal.RK2(f)
    rk3 = TTCal.RK3(f)
    rk4 = TTCal.RK4(f)
    exp1 = [exp(1)-1]

    err2 = norm(rk2([1.0]) - exp1)
    err3 = norm(rk3([1.0]) - exp1)
    err4 = norm(rk4([1.0]) - exp1)

    @test rk2([1.0]) == [1.5]
    @test err2 > err3 > err4
end

