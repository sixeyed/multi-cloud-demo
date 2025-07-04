FROM mcr.microsoft.com/dotnet/runtime:9.0 AS base
WORKDIR /app

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY ["BackgroundWorker/BackgroundWorker.csproj", "BackgroundWorker/"]
COPY ["MultiCloudDemo.Shared/MultiCloudDemo.Shared.csproj", "MultiCloudDemo.Shared/"]
RUN dotnet restore "BackgroundWorker/BackgroundWorker.csproj"
COPY ["BackgroundWorker/", "BackgroundWorker/"]
COPY ["MultiCloudDemo.Shared/", "MultiCloudDemo.Shared/"]
RUN dotnet build "BackgroundWorker/BackgroundWorker.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "BackgroundWorker/BackgroundWorker.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "BackgroundWorker.dll"]