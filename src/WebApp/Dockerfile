FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY ["WebApp/WebApp.csproj", "WebApp/"]
COPY ["MultiCloudDemo.Shared/MultiCloudDemo.Shared.csproj", "MultiCloudDemo.Shared/"]
RUN dotnet restore "WebApp/WebApp.csproj"
COPY ["WebApp/", "WebApp/"]
COPY ["MultiCloudDemo.Shared/", "MultiCloudDemo.Shared/"]
RUN dotnet build "WebApp/WebApp.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "WebApp/WebApp.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "WebApp.dll"]