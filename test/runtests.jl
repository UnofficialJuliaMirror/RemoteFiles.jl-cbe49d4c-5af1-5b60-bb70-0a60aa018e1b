using RemoteFiles
using Dates: DateTime
using Test

rm("image.png", force=true)
rm("tmp", force=true, recursive=true)

function capture_stderr(f::Function)
    let fname = tempname()
        try
            open(fname, "w") do fout
                redirect_stderr(fout) do
                    f()
                end
            end
            return read(fname, String)
        finally
            rm(fname, force=true)
        end
    end
end

@testset "RemoteFiles" begin
    @testset "RemoteFile" begin
        r = RemoteFile("https://httpbin.org/image/png")
        @test r.file == "png"
        r = RemoteFile("https://httpbin.org/image/png", file="image.png")
        @test r.file == "image.png"


        output = capture_stderr() do
            download(r, verbose=true)
        end
        #= @test occursin("Downloading", output) =#
        #= @test occursin("successfully downloaded", output) =#
        @test isfile(r)
        rm(r, force=true)

        r = RemoteFile("https://httpbin.org/image/png", file="image.png", dir="tmp")
        download(r)
        @test isfile(r)
        rm(r, force=true)

        @test_throws ArgumentError RemoteFile("garbage")

        r = RemoteFile("https://garbage/garbage/garbage.garbage", wait=0, retries=0)
        @test_throws ErrorException download(r)

        r = RemoteFile("https://garbage/garbage/garbage.garbage", wait=0, retries=0, failed=:warn)
        @test_throws ErrorException download(r)

        r = RemoteFile("https://httpbin.org/image/png", file="image.png", updates=:never)
        download(r)
        c1 = lastupdate(r)
        output = capture_stderr() do
            download(r, verbose=true)
        end
        #= @test occursin("up-to-date", output) =#
        c2 = lastupdate(r)
        @test c1 == c2
        rm(r, force=true)

        r = RemoteFile("https://httpbin.org/image/png", file="image.png", updates=:always)
        download(r)
        c1 = lastupdate(r)
        sleep(1)
        download(r)
        c2 = lastupdate(r)
        @test c1 == c2
        rm(r, force=true)

        r = RemoteFile("https://httpbin.org/image/png", file="image.png", updates=:always)
        download(r)
        r = RemoteFile("https://garbage/garbage/garbage.garbage", file="image.png",
            wait=1, retries=1, failed=:warn, updates=:always)
        output = capture_stderr() do
            download(r, verbose=true)
        end
        #= @test occursin("failed", output) =#
        #= @test occursin("Retrying", output) =#
        #= @test occursin("Local file was not updated.", output) =#
        rm(r, force=true)

        @RemoteFile r "https://httpbin.org/image/png" file="image.png"
        download(r)
        @test isfile(r)
        rm(r, force=true)

        dir = "data"
        @RemoteFile r "https://httpbin.org/image/png" file="image.png" dir=dir
        r1 = @RemoteFile "https://httpbin.org/image/png" file="image.png" dir=dir
        download(r)
        download(r1)
        @test isdir(dir)
        @test isfile(r)
        @test isfile(r1)
        rm(dir, force=true, recursive=true)
    end

    @testset "RemoteFileSets" begin
        set = RemoteFileSet("Images",
            file1=RemoteFile("https://httpbin.org/image/png", file="image1.png"),
            file2=RemoteFile("https://httpbin.org/image/png", file="image2.png"),
        )
        rm(set, force=true)
        download(set)
        @test isfile(set[:file1])
        @test isfile(set[:file2])
        @test isfile(set["file1"])
        @test isfile(set["file2"])
        @test isfile(set)
        rm(set)

        @RemoteFileSet set "Images" begin
            file1 = @RemoteFile "https://httpbin.org/image/png" file="image1.png"
            file2 = @RemoteFile "https://httpbin.org/image/png" file="image2.png"
        end
        download(set)
        @test isfile(set, :file1)
        @test isfile(set, :file2)
        @test all(map(isfile, paths(set)))
        @test isfile(set)
        rm(set, :file1, force=true)
        rm(set, :file2, force=true)

        dir = "data"
        @RemoteFileSet set "Images" begin
            file1 = @RemoteFile "https://httpbin.org/image/png" file="image1.png" dir=dir
        end
        download(set)
        @test isdir(dir)
        rm(dir, force=true, recursive=true)
    end

    @testset "Updates" begin
        @test RemoteFiles.samecontent(@__FILE__, @__FILE__) == true

        updates = :helllottatimes
        last = DateTime(2017, 2, 28)
        now = DateTime(2017, 3, 6)
        @test_throws ErrorException RemoteFiles.isoutdated(last, now, updates)

        updates = :mondays
        last = DateTime(2017, 2, 28)
        now = DateTime(2017, 3, 6)
        @test RemoteFiles.isoutdated(last, now, updates) == true
        last = DateTime(2017, 2, 28)
        now = DateTime(2017, 3, 1)
        @test RemoteFiles.isoutdated(last, now, updates) == false

        updates = :tuesdays
        last = DateTime(2017, 2, 28)
        now = DateTime(2017, 3, 7)
        @test RemoteFiles.isoutdated(last, now, updates) == true
        last = DateTime(2017, 2, 28)
        now = DateTime(2017, 3, 1)
        @test RemoteFiles.isoutdated(last, now, updates) == false

        updates = :wednesdays
        last = DateTime(2017, 2, 28)
        now = DateTime(2017, 3, 6)
        @test RemoteFiles.isoutdated(last, now, updates) == true
        last = DateTime(2017, 2, 28)
        now = DateTime(2017, 2, 28)
        @test RemoteFiles.isoutdated(last, now, updates) == false

        updates = :thursdays
        last = DateTime(2017, 2, 28)
        now = DateTime(2017, 3, 6)
        @test RemoteFiles.isoutdated(last, now, updates) == true
        last = DateTime(2017, 2, 28)
        now = DateTime(2017, 3, 1)
        @test RemoteFiles.isoutdated(last, now, updates) == false

        updates = :fridays
        last = DateTime(2017, 2, 28)
        now = DateTime(2017, 3, 6)
        @test RemoteFiles.isoutdated(last, now, updates) == true
        last = DateTime(2017, 2, 28)
        now = DateTime(2017, 3, 1)
        @test RemoteFiles.isoutdated(last, now, updates) == false

        updates = :saturdays
        last = DateTime(2017, 2, 28)
        now = DateTime(2017, 3, 6)
        @test RemoteFiles.isoutdated(last, now, updates) == true
        last = DateTime(2017, 2, 28)
        now = DateTime(2017, 3, 1)
        @test RemoteFiles.isoutdated(last, now, updates) == false

        updates = :sundays
        last = DateTime(2017, 2, 28)
        now = DateTime(2017, 3, 6)
        @test RemoteFiles.isoutdated(last, now, updates) == true
        last = DateTime(2017, 2, 28)
        now = DateTime(2017, 3, 2)
        @test RemoteFiles.isoutdated(last, now, updates) == false

        updates = :yearly
        last = DateTime(2017, 2, 28)
        now = DateTime(2018, 3, 5)
        @test RemoteFiles.isoutdated(last, now, updates) == true
        last = DateTime(2017, 2, 28)
        now = DateTime(2017, 3, 1)
        @test RemoteFiles.isoutdated(last, now, updates) == false

        updates = :monthly
        last = DateTime(2017, 2, 28)
        now = DateTime(2017, 3, 6)
        @test RemoteFiles.isoutdated(last, now, updates) == true
        last = DateTime(2017, 2, 28)
        now = DateTime(2017, 2, 20)
        @test RemoteFiles.isoutdated(last, now, updates) == false

        updates = :weekly
        last = DateTime(2017, 2, 28)
        now = DateTime(2017, 3, 6)
        @test RemoteFiles.isoutdated(last, now, updates) == true
        last = DateTime(2017, 2, 28)
        now = DateTime(2017, 3, 1)
        @test RemoteFiles.isoutdated(last, now, updates) == false

        updates = :daily
        last = DateTime(2017, 2, 28)
        now = DateTime(2017, 3, 1)
        @test RemoteFiles.isoutdated(last, now, updates) == true
        last = DateTime(2017, 2, 28)
        now = DateTime(2017, 2, 28)
        @test RemoteFiles.isoutdated(last, now, updates) == false
    end
end
