# Utilities for testing DSGE.jl
using Base.Test



# minusnan(x, y) evaluates x-y in a way that treats NaN like Inf and sets Inf - Inf = 0
minusnan{S<:FloatingPoint, T<:FloatingPoint}(x::S, y::T) =  minusnan(complex(x), complex(y))

function minusnan{S<:FloatingPoint, T<:FloatingPoint}(x::Complex{S}, y::Complex{T})
    x = isnan(x) || isinf(x) ? Inf : x
    y = isnan(y) || isinf(y) ? Inf : y
    return isinf(x) && isinf(y) ? 0 : x - y
end



# TODO: decide what a sensible default ε value is for our situation
# Compares matrices, reports absolute differences, returns true if all entries close enough
function test_matrix_eq{R<:FloatingPoint, S<:FloatingPoint, T<:FloatingPoint}(expected::Array{R},
             actual::Array{S}, ε::T = 1e-4; noisy::Bool = false)
    return test_matrix_eq(complex(expected), complex(actual), ε; noisy=noisy)
end

# Complex-valued input matrices
function test_matrix_eq{R<:FloatingPoint, S<:FloatingPoint, T<:FloatingPoint}(expected::
             Array{Complex{R}}, actual::Array{Complex{S}}, ε::T = 1e-4; noisy::Bool = false)
    # Matrices of different sizes return false
    if size(expected) != size(actual)
        if noisy
            println("Size expected $(size(expected)), actual $(size(actual))\n")
        end
        return false
    end

    n_dims = ndims(expected)
    n_entries = length(expected)
    
    # Count differences and find max    
    abs_diff = abs(map(minusnan, expected, actual))
    n_neq = countnz(abs_diff)
    n_not_approx_eq = count(x -> x > ε, abs_diff)
    max_abs_diff = maximum(abs_diff)
    max_inds = ind2sub(size(abs_diff), indmax(abs_diff))
    
    # Print output
    if noisy
        println("$n_neq of $n_entries entries with abs diff > 0")
        println("$n_not_approx_eq of $n_entries entries with abs diff > $ε")
        if n_neq != 0
            println("Max abs diff of $max_abs_diff at entry $max_inds\n")
        else
            println("Max abs diff of 0\n")
        end
    end

    # Return true if all entries within ε
    return n_not_approx_eq == 0
end



# Complex numbers are parsed weirdly from readcsv, so we build a complex array using regex
function readcsv_complex(file::String)
    matrix_str = readcsv(file)
    rows, cols = size(matrix_str)
    matrix = complex(zeros(size(matrix_str)))

    for j = 1:cols
        for i = 1:rows
            value = matrix_str[i, j]
            if isa(value, String)
                m = match(r"(\d+\.?\d*e?-?\d*) ?([+-]) ?(\d+\.?\d*+e?-?\d*)im?", value)
                if m == nothing
                    error("Regex didn't match anything at ($i, $j) entry")
                end
                a = parse(m.captures[1])
                b = parse(m.captures[2] * m.captures[3])
                matrix[i, j] = complex(a, b)
            elseif isa(value, Number)
                matrix[i, j] = complex(value)
            else
                error("($i, $j) entry not a string or number")
            end
        end
    end
    return matrix
end



function test_util()
    test_test_matrix_eq()
    test_readcsv_complex()
    println("### All tests in util.jl tests passed\n")
end


function test_test_matrix_eq()
    # Matrices of different sizes returns false
    m0 = zeros(2, 3)
    m1 = zeros(2, 2)
    @test !test_matrix_eq(m0, m1)

    # Returns true
    m2 = [0.0001 0.0; 0.0 -0.0001]
    @test test_matrix_eq(m1, m2)

    # Returns false
    m3 = [0.0001 0.0; 0.0 -0.0002]
    @test !test_matrix_eq(m1, m3)
    @test test_matrix_eq(m1, m3, 2e-4) # but true with larger ε

    # Arguments of different float type returns true
    m2_float16 = convert(Array{Float16, 2}, m2)
    ε = convert(Float32, 0.0001)
    @test test_matrix_eq(m1, m2)

    # Complex-valued matrices
    @test test_matrix_eq(complex(m1), complex(m2))
    @test !test_matrix_eq(complex(m1), complex(m3))

    # 3D arrays
    m4 = zeros(2, 2, 2)
    m5 = ones(2, 2, 2)
    @test !test_matrix_eq(m4, m5)
    
    println("test_matrix_eq tests passed\n")
end



function test_readcsv_complex()
    readcsv_complex("test_readcsv_complex.csv")
    println("readcsv_complex tests passed\n")
end